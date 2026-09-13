import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

function clean(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalize(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function uniqueParts(values: string[]): string[] {
  const seen = new Set<string>();
  const output: string[] = [];

  for (const value of values) {
    const trimmed = value.trim();

    if (!trimmed) continue;

    const key = trimmed.toLowerCase();

    if (seen.has(key)) continue;

    seen.add(key);
    output.push(trimmed);
  }

  return output;
}

function mapNominatimPlace(row: Record<string, unknown>) {
  const address =
    row.address && typeof row.address === "object"
      ? row.address as Record<string, unknown>
      : {};

  const city =
    clean(address.city) ||
    clean(address.town) ||
    clean(address.village) ||
    clean(address.municipality) ||
    clean(address.hamlet) ||
    clean(address.county);

  const state = clean(address.state);

  const stateCode =
    clean(address["ISO3166-2-lvl4"]).replace(/^US-/i, "");

  const country = clean(address.country);
  const countryCode = clean(address.country_code).toLowerCase();

  const displayName = clean(row.display_name);

  const firstPart =
    clean(row.name) ||
    city ||
    displayName.split(",")[0]?.trim() ||
    "Location";

  const subtitleParts = uniqueParts([
    city,
    state,
    country,
  ]).filter(
    (value) => value.toLowerCase() !== firstPart.toLowerCase(),
  );

  return {
    name: firstPart,
    subtitle:
      subtitleParts.length > 0
        ? subtitleParts.join(", ")
        : displayName,
    full_name: displayName,
    city,
    state,
    state_code: stateCode,
    country,
    country_code: countryCode,
    type: clean(row.type),
    addresstype: clean(row.addresstype),
    category: clean(row.category),
    importance:
      typeof row.importance === "number"
        ? row.importance
        : Number(row.importance) || 0,
    lat: Number(row.lat),
    lng: Number(row.lon),
    source: "nominatim",
  };
}

function mapDatabaseCity(row: Record<string, unknown>) {
  const name = clean(row.name);
  const state = clean(row.state_name);
  const stateCode = clean(row.state_code);
  const population = Number(row.population) || 0;

  const subtitle = stateCode
    ? `${state}, ${stateCode}`
    : state;

  const fullName = stateCode
    ? `${name}, ${stateCode}, United States`
    : `${name}, ${state}, United States`;

  return {
    name,
    subtitle,
    full_name: fullName,
    city: name,
    state,
    state_code: stateCode,
    country: "United States",
    country_code: "us",
    type: "city",
    addresstype: "city",
    category: "place",
    importance: Math.log10(Math.max(population, 1) + 1),
    population,
    lat: Number(row.latitude),
    lng: Number(row.longitude),
    geoname_id: row.geoname_id,
    feature_code: clean(row.feature_code),
    source: "us_cities",
  };
}

function parseSearchQuery(rawQuery: string) {
  const parts = rawQuery
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);

  const cityQuery = normalize(parts[0] ?? rawQuery);

  const stateQuery =
    parts.length > 1
      ? normalize(parts[1])
      : "";

  return {
    cityQuery,
    stateQuery,
  };
}

async function searchCityDatabase(
  query: string,
): Promise<Record<string, unknown>[]> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Supabase environment is unavailable.");
  }

  const supabase = createClient(
    supabaseUrl,
    supabaseAnonKey,
    {
      auth: {
        persistSession: false,
      },
    },
  );

  const {
    cityQuery,
    stateQuery,
  } = parseSearchQuery(query);

  if (cityQuery.length < 2) {
    return [];
  }

  let request = supabase
    .from("us_cities")
    .select(
      [
        "geoname_id",
        "name",
        "ascii_name",
        "normalized_name",
        "state_code",
        "state_name",
        "population",
        "latitude",
        "longitude",
        "feature_code",
      ].join(","),
    )
    .ilike("normalized_name", `${cityQuery}%`)
    .order("population", {
      ascending: false,
    })
    .limit(100);

  if (stateQuery) {
    if (stateQuery.length === 2) {
      request = request.ilike(
        "state_code",
        stateQuery,
      );
    } else {
      request = request.ilike(
        "state_name",
        `${stateQuery}%`,
      );
    }
  }

  const {
    data,
    error,
  } = await request;

  if (error) {
    throw new Error(
      `City database search failed: ${error.message}`,
    );
  }

  const rows = Array.isArray(data)
    ? data
    : [];

  const exact: Record<string, unknown>[] = [];
  const prefix: Record<string, unknown>[] = [];

  const seen = new Set<string>();

  for (const rawRow of rows) {
    const row = rawRow as Record<string, unknown>;

    const name = normalize(clean(row.normalized_name));

    const key = [
      name,
      normalize(clean(row.state_code)),
    ].join("|");

    if (seen.has(key)) {
      continue;
    }

    seen.add(key);

    const mapped = mapDatabaseCity(row);

    if (name === cityQuery) {
      exact.push(mapped);
    } else {
      prefix.push(mapped);
    }
  }

  function sortPopulation(
    a: Record<string, unknown>,
    b: Record<string, unknown>,
  ) {
    const populationDifference =
      (Number(b.population) || 0) -
      (Number(a.population) || 0);

    if (populationDifference !== 0) {
      return populationDifference;
    }

    const aName = normalize(clean(a.name));
    const bName = normalize(clean(b.name));

    const nameDifference =
      aName.localeCompare(bName);

    if (nameDifference !== 0) {
      return nameDifference;
    }

    return clean(a.state_code).localeCompare(
      clean(b.state_code),
    );
  }

  exact.sort(sortPopulation);
  prefix.sort(sortPopulation);

  return [
    ...exact,
    ...prefix,
  ].slice(0, 20);
}

async function reverseNominatim(
  lat: number,
  lng: number,
): Promise<Record<string, unknown>> {
  const url = new URL(
    "https://nominatim.openstreetmap.org/reverse",
  );

  url.searchParams.set("lat", String(lat));
  url.searchParams.set("lon", String(lng));
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("accept-language", "en");

  const response = await fetch(
    url.toString(),
    {
      headers: {
        "User-Agent":
          "999-Wellness-Intelligence/1.0",
        "Accept": "application/json",
      },
    },
  );

  if (!response.ok) {
    throw new Error(
      "Reverse geocoding unavailable.",
    );
  }

  const row = await response.json();

  return mapNominatimPlace(
    row as Record<string, unknown>,
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(
      "ok",
      {
        headers,
      },
    );
  }

  try {
    const body = await req.json();

    const action = clean(body.action);

    if (action === "search") {
      const query = clean(body.query);

      if (query.length < 2) {
        return new Response(
          JSON.stringify({
            results: [],
          }),
          {
            headers,
          },
        );
      }

      const results =
        await searchCityDatabase(query);

      return new Response(
        JSON.stringify({
          results,
          source: "us_cities",
        }),
        {
          headers,
        },
      );
    }

    if (action === "reverse") {
      const lat = Number(body.lat);
      const lng = Number(body.lng);

      if (
        !Number.isFinite(lat) ||
        !Number.isFinite(lng)
      ) {
        throw new Error(
          "Invalid coordinates.",
        );
      }

      const place =
        await reverseNominatim(
          lat,
          lng,
        );

      return new Response(
        JSON.stringify({
          place,
        }),
        {
          headers,
        },
      );
    }

    return new Response(
      JSON.stringify({
        error: "Unsupported action.",
      }),
      {
        status: 400,
        headers,
      },
    );
  } catch (error) {
    console.error(
      "place-search error:",
      error,
    );

    return new Response(
      JSON.stringify({
        error:
          error instanceof Error
            ? error.message
            : "Location lookup failed.",
      }),
      {
        status: 500,
        headers,
      },
    );
  }
});
