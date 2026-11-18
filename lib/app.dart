import 'package:flutter/material.dart';

import 'data.dart';
import 'widgets.dart';
import 'catalog.dart';
import 'trips.dart';
import 'commerce.dart';

class JasTipGo extends StatelessWidget {
  const JasTipGo({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => MaterialApp(
      title: 'JasTipGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'DM Sans',
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(seedColor: teal, surface: paper),
        appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -1.3,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD5DDD5)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            backgroundColor: teal,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      // Recreate the navigator when identity or role changes, clearing protected pages.
      key: ValueKey('${session.userId}:${session.role}'),
      home: session.user == null
          ? AuthScreen(session: session)
          : HomeScreen(session: session),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session});
  final Session session;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.authenticate(_register ? 'register' : 'login', {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.shopping_bag_outlined, color: teal, size: 64),
                const SizedBox(height: 12),
                Text(
                  'JasTipGo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Titip dari mana saja.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: teal),
                ),
                const SizedBox(height: 40),
                Text(
                  _register ? 'Buat akun' : 'Selamat datang kembali',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                if (_register) Input(_name, 'Nama lengkap'),
                Input(
                  _email,
                  'Email',
                  validator: (value) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Masukkan email yang valid',
                ),
                Input(
                  _password,
                  'Password',
                  secret: true,
                  validator: (value) =>
                      (value?.length ?? 0) < (_register ? 8 : 1)
                      ? 'Password minimal ${_register ? 8 : 1} karakter'
                      : null,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                SubmitButton(
                  busy: _busy,
                  onPressed: _submit,
                  label: _register ? 'Daftar' : 'Masuk',
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _register = !_register;
                          _error = null;
                        }),
                  child: Text(
                    _register
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Daftar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});
  final Session session;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final pages = [
      CatalogScreen(session: session),
      TripsScreen(session: session),
      OrdersScreen(session: session),
      WalletScreen(session: session),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'JasTipGo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Aktivitas',
            onPressed: () => openPage(context, InboxScreen(session: session)),
            icon: const Icon(Icons.notifications_none),
          ),
          if (!session.isSeller)
            IconButton(
              tooltip: 'Keranjang',
              onPressed: () => openPage(context, CartScreen(session: session)),
              icon: const Icon(Icons.shopping_bag_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.account_circle_outlined, size: 56, color: teal),
              const SizedBox(height: 16),
              Text(
                session.user!.string('name'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(session.user!.string('email')),
              const SizedBox(height: 24),
              Text(
                'Peran aktif · ${session.isSeller ? 'Jastiper' : 'Penitip'}',
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () async => session.switchRole(),
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  'Jadi ${session.isSeller ? 'Penitip' : 'Jastiper'}',
                ),
              ),
              const Divider(height: 40),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Keluar'),
                onTap: () async {
                  await perform(context, session.logout);
                },
              ),
              const SizedBox(height: 24),
              SelectableText(
                session.baseUrl,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Peta © OpenStreetMap contributors',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff),
            label: 'Trip',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Saldo',
          ),
        ],
      ),
    );
  }
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aktivitas')),
    body: DataView(
      load: () => session.request('inbox'),
      builder: (data, reload) {
        final rows = records(data);
        return PageBody(
          children: [
            if (rows.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    if (await perform(context, () async {
                      await session.request('read_inbox');
                    })) {
                      reload();
                    }
                  },
                  child: const Text('Tandai semua dibaca'),
                ),
              ),
            if (rows.isEmpty) const EmptyState('Belum ada aktivitas.'),
            ...rows.map(
              (row) => Card(
                child: ListTile(
                  leading: Icon(
                    row.number('is_read') == 0
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none,
                    color: teal,
                  ),
                  title: Text(row.string('message')),
                  subtitle: Text(row.string('created_at')),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
