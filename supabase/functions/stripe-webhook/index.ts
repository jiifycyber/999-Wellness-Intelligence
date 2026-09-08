import Stripe from 'npm:stripe@^22'
import { createClient } from 'npm:@supabase/supabase-js@2'

const stripeSecret = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const stripe = new Stripe(stripeSecret)
const cryptoProvider = Stripe.createSubtleCryptoProvider()

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
    },
  })
}

async function markBookingPaid(
  admin: any,
  session: Stripe.Checkout.Session,
) {
  const bookingId =
    session.metadata?.booking_id ??
    session.client_reference_id ??
    ''

  if (!bookingId) {
    console.error('Stripe session missing booking_id')
    return
  }

  const paymentIntentId =
    typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id ?? ''

  let chargeId: string | null = null
  let transferId: string | null = null

  if (paymentIntentId) {
    const paymentIntent = await stripe.paymentIntents.retrieve(
      paymentIntentId,
      {
        expand: ['latest_charge'],
      },
    )

    if (typeof paymentIntent.latest_charge === 'string') {
      chargeId = paymentIntent.latest_charge
    } else if (paymentIntent.latest_charge) {
      chargeId = paymentIntent.latest_charge.id

      const transfer = paymentIntent.latest_charge.transfer

      if (typeof transfer === 'string') {
        transferId = transfer
      } else if (transfer) {
        transferId = transfer.id
      }
    }
  }

  const { error } = await admin
    .from('bookings')
    .update({
      payment_status: 'Paid',
      stripe_payment_intent_id: paymentIntentId || null,
      stripe_charge_id: chargeId,
      stripe_transfer_id: transferId,
      payment_completed_at: new Date().toISOString(),
      payment_failed_at: null,
    })
    .eq('id', bookingId)

  if (error) {
    throw error
  }

  console.log('Booking marked Paid:', bookingId)
}

async function markBookingFailed(
  admin: any,
  bookingId: string,
  paymentIntentId: string | null,
) {
  if (!bookingId) return

  const { error } = await admin
    .from('bookings')
    .update({
      payment_status: 'Failed',
      stripe_payment_intent_id: paymentIntentId,
      payment_failed_at: new Date().toISOString(),
    })
    .eq('id', bookingId)

  if (error) {
    throw error
  }

  console.log('Booking marked Failed:', bookingId)
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  if (!stripeSecret) {
    return json({ error: 'STRIPE_SECRET_KEY missing' }, 500)
  }

  if (!webhookSecret) {
    return json({ error: 'STRIPE_WEBHOOK_SECRET missing' }, 500)
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase environment incomplete' }, 500)
  }

  const signature = req.headers.get('stripe-signature') ?? ''
  const rawBody = await req.text()

  let event: Stripe.Event

  try {
    event = await stripe.webhooks.constructEventAsync(
      rawBody,
      signature,
      webhookSecret,
      undefined,
      cryptoProvider,
    )
  } catch (error) {
    console.error('Invalid Stripe signature', error)
    return json({ error: 'Invalid Stripe signature' }, 400)
  }

  const admin = createClient(supabaseUrl, serviceRoleKey)

  try {
    if (
      event.type === 'checkout.session.completed' ||
      event.type === 'checkout.session.async_payment_succeeded'
    ) {
      const session =
        event.data.object as Stripe.Checkout.Session

      if (
        event.type === 'checkout.session.completed' &&
        session.payment_status !== 'paid'
      ) {
        console.log(
          'Checkout completed but payment not final yet:',
          session.id,
        )
      } else {
        await markBookingPaid(admin, session)
      }
    }

    if (event.type === 'checkout.session.async_payment_failed') {
      const session =
        event.data.object as Stripe.Checkout.Session

      const bookingId =
        session.metadata?.booking_id ??
        session.client_reference_id ??
        ''

      const paymentIntentId =
        typeof session.payment_intent === 'string'
          ? session.payment_intent
          : session.payment_intent?.id ?? null

      await markBookingFailed(
        admin,
        bookingId,
        paymentIntentId,
      )
    }

    if (event.type === 'payment_intent.payment_failed') {
      const paymentIntent =
        event.data.object as Stripe.PaymentIntent

      const bookingId =
        paymentIntent.metadata?.booking_id ?? ''

      await markBookingFailed(
        admin,
        bookingId,
        paymentIntent.id,
      )
    }

    return json({
      received: true,
      type: event.type,
    })
  } catch (error) {
    console.error('Webhook processing failed', error)

    return json(
      {
        error:
          error instanceof Error
            ? error.message
            : 'Webhook processing failed',
      },
      500,
    )
  }
})
