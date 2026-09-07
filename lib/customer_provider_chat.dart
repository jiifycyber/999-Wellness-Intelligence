import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerProviderChatScreen extends StatefulWidget {
  const CustomerProviderChatScreen({super.key, required this.providerName});

  final String providerName;

  @override
  State<CustomerProviderChatScreen> createState() =>
      _CustomerProviderChatScreenState();
}

class _CustomerProviderChatScreenState
    extends State<CustomerProviderChatScreen> {
  final TextEditingController controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  String? providerId;
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> loadMessages() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Please sign in to use messaging.';
      });
      return;
    }

    try {
      final provider = await Supabase.instance.client
          .from('provider_profiles')
          .select('id')
          .eq('professional_name', widget.providerName)
          .maybeSingle();

      final id = provider?['id']?.toString();

      if (id == null || id.isEmpty) {
        throw Exception('Provider account not found.');
      }

      final sent = await Supabase.instance.client
          .from('messages')
          .select('id, sender_id, receiver_id, message, read_at, created_at')
          .eq('sender_id', user.id)
          .eq('receiver_id', id);

      final received = await Supabase.instance.client
          .from('messages')
          .select('id, sender_id, receiver_id, message, read_at, created_at')
          .eq('sender_id', id)
          .eq('receiver_id', user.id);

      final rows = <Map<String, dynamic>>[];

      for (final row in sent as List) {
        rows.add(Map<String, dynamic>.from(row as Map));
      }

      for (final row in received as List) {
        rows.add(Map<String, dynamic>.from(row as Map));
      }

      rows.sort((a, b) {
        final left = a['created_at']?.toString() ?? '';
        final right = b['created_at']?.toString() ?? '';
        return left.compareTo(right);
      });

      if (!mounted) return;

      setState(() {
        providerId = id;
        messages = rows;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Unable to load this conversation.';
      });
    }
  }

  Future<void> sendMessage() async {
    final user = Supabase.instance.client.auth.currentUser;
    final id = providerId;
    final body = controller.text.trim();

    if (user == null || id == null || body.isEmpty || sending) {
      return;
    }

    setState(() {
      sending = true;
    });

    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': id,
        'message': body,
      });

      controller.clear();
      await loadMessages();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message could not be sent.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E18),
        foregroundColor: Colors.white,
        title: Text(widget.providerName),
        actions: [
          IconButton(
            onPressed: loadMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Start the conversation.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final row = messages[index];
                      final mine =
                          row['sender_id']?.toString() == currentUserId;
                      final body = row['message']?.toString() ?? '';

                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? const Color(0xFF7138D9)
                                : const Color(0xFF171C2A),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            body,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              color: const Color(0xFF0B0E18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.providerName}',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF151A27),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton.filled(
                    onPressed: sending ? null : sendMessage,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
