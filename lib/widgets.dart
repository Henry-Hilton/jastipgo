import 'package:flutter/material.dart';

import 'data.dart';

const ink = Color(0xFF153B38);
const teal = Color(0xFF18776C);
const paper = Color(0xFFF7F6F0);
const orange = Color(0xFFE47745);
Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
void showMessage(BuildContext context, Object message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$message')));
}

Future<bool> perform(BuildContext context, Future<void> Function() work) async {
  try {
    await work();
    return true;
  } catch (error) {
    if (context.mounted) showMessage(context, error);
    return false;
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    ) ??
    false;

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1050),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: children,
      ),
    ),
  );
}

class DataView extends StatefulWidget {
  const DataView({super.key, required this.load, required this.builder});
  final Future<dynamic> Function() load;
  final Widget Function(dynamic data, VoidCallback reload) builder;
  @override
  State<DataView> createState() => DataViewState();
}

class DataViewState extends State<DataView> {
  late Future<dynamic> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void reload() {
    if (mounted) setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40, color: teal),
                const SizedBox(height: 16),
                Text('${snapshot.error}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: reload, child: const Text('Coba lagi')),
              ],
            ),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async {
          reload();
          try {
            await _future;
          } catch (_) {
            // The FutureBuilder renders the fetch error and retry action.
          }
        },
        child: widget.builder(snapshot.data, reload),
      );
    },
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.travel_explore});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(icon, size: 48, color: teal),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

class Photo extends StatelessWidget {
  const Photo(
    this.url, {
    super.key,
    this.height = 180,
    this.fit = BoxFit.cover,
  });
  final String url;
  final double height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      color: const Color(0xFFE8EDE5),
      alignment: Alignment.center,
      child: const Icon(Icons.shopping_bag_outlined, size: 44, color: teal),
    );
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class StatusLabel extends StatelessWidget {
  const StatusLabel(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Text(
    statusNames[status] ?? status,
    style: const TextStyle(color: teal, fontWeight: FontWeight.w700),
  );
}

class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.label,
  });
  final bool busy;
  final VoidCallback onPressed;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Wajib diisi' : null;
String? positiveNumber(String? value) => (int.tryParse(value ?? '') ?? 0) <= 0
    ? 'Masukkan angka lebih dari 0'
    : null;

class Input extends StatelessWidget {
  const Input(
    this.controller,
    this.label, {
    super.key,
    this.lines = 1,
    this.number = false,
    this.secret = false,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final int lines;
  final bool number;
  final bool secret;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      obscureText: secret,
      maxLines: lines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      validator: validator ?? requiredText,
    ),
  );
}
