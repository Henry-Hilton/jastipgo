import 'package:flutter/material.dart';

import 'data.dart';
import 'widgets.dart';
import 'trips.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.session});
  final Session session;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _busy = false;
  String _checkoutKey = operationKey();
  Future<void> _quantity(Json item, int quantity, VoidCallback reload) async {
    setState(() => _busy = true);
    if (await perform(context, () async {
      await widget.session.request('cart_set', {
        'product_id': item.number('id'),
        'quantity': quantity,
      });
    })) {
      _checkoutKey = operationKey();
      reload();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Keranjang')),
    body: DataView(
      load: () => widget.session.request('cart'),
      builder: (data, reload) {
        final items = records(data);
        final total = items.fold<int>(
          0,
          (sum, item) => sum + item.number('price') * item.number('quantity'),
        );
        return PageBody(
          children: [
            if (items.isEmpty)
              const EmptyState(
                'Keranjang masih kosong.',
                icon: Icons.shopping_bag_outlined,
              ),
            ...items.map(
              (item) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.string('trip_name'),
                        style: const TextStyle(color: teal),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.string('name'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${money(item.number('price'))} · Stok ${item.number('stock')}',
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Kurangi jumlah',
                            onPressed: _busy
                                ? null
                                : () => _quantity(
                                    item,
                                    item.number('quantity') - 1,
                                    reload,
                                  ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${item.number('quantity')}'),
                          IconButton(
                            tooltip: 'Tambah jumlah',
                            onPressed: _busy
                                ? null
                                : () => _quantity(
                                    item,
                                    item.number('quantity') + 1,
                                    reload,
                                  ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Hapus barang',
                            onPressed: _busy
                                ? null
                                : () => _quantity(item, 0, reload),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Total ${money(total)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pembayaran memakai saldo. Dana diterima jastiper setelah kamu mengonfirmasi pesanan selesai.',
              ),
              SubmitButton(
                busy: _busy,
                label: 'Bayar & checkout',
                onPressed: () async {
                  if (!await confirm(
                    context,
                    'Bayar pesanan?',
                    '${money(total)} akan dipotong dari saldo. Harga dan stok diperiksa kembali oleh server.',
                  )) {
                    return;
                  }
                  if (!mounted || !context.mounted) return;
                  setState(() => _busy = true);
                  final ok = await perform(context, () async {
                    await widget.session.request('checkout', {
                      'operation_key': _checkoutKey,
                    });
                  });
                  if (mounted && context.mounted) {
                    setState(() => _busy = false);
                    if (ok) {
                      _checkoutKey = operationKey();
                      reload();
                      showMessage(
                        context,
                        'Checkout berhasil. Lihat perkembangan di Pesanan.',
                      );
                    }
                  }
                },
              ),
            ],
          ],
        );
      },
    ),
  );
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.session});
  final Session session;
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amount = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _key = operationKey();
  bool _busy = false;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DataView(
    load: () => widget.session.request('wallet'),
    builder: (value, reload) {
      final wallet = value as Json;
      return PageBody(
        children: [
          const SizedBox(height: 12),
          const Text(
            'Saldo tersedia',
            style: TextStyle(fontSize: 16, color: teal),
          ),
          const SizedBox(height: 8),
          Text(
            money(wallet.number('balance')),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 28),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Input(
                  _amount,
                  'Nominal top-up (Rp1.000–Rp10.000.000)',
                  number: true,
                  validator: (value) {
                    final amount = int.tryParse(value ?? '') ?? 0;
                    return amount < 1000 || amount > 10000000
                        ? 'Nominal Rp1.000 sampai Rp10.000.000'
                        : null;
                  },
                ),
                SubmitButton(
                  busy: _busy,
                  label: 'Top-up saldo',
                  onPressed: () async {
                    if (!_form.currentState!.validate()) return;
                    setState(() => _busy = true);
                    final ok = await perform(context, () async {
                      await widget.session.request('topup', {
                        'amount': int.parse(_amount.text),
                        'operation_key': _key,
                      });
                    });
                    if (mounted && context.mounted) {
                      setState(() => _busy = false);
                      if (ok) {
                        _key = operationKey();
                        _amount.clear();
                        reload();
                        showMessage(context, 'Saldo berhasil ditambahkan.');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          Text('Riwayat saldo', style: Theme.of(context).textTheme.titleLarge),
          if (wallet.rows('ledger').isEmpty)
            const EmptyState(
              'Belum ada transaksi saldo.',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ...wallet
              .rows('ledger')
              .map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    entry.number('amount') > 0
                        ? Icons.south_west
                        : Icons.north_east,
                    color: teal,
                  ),
                  title: Text(entry.string('description')),
                  subtitle: Text(entry.string('created_at')),
                  trailing: Text(
                    '${entry.number('amount') > 0 ? '+' : ''}${money(entry.number('amount'))}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.session});
  final Session session;
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => DataView(
    load: () => widget.session.request('orders'),
    builder: (data, reload) {
      final orders = records(data);
      return PageBody(
        children: [
          Text(
            widget.session.isSeller ? 'Pesanan masuk' : 'Pesanan saya',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          if (orders.isEmpty)
            const EmptyState(
              'Belum ada pesanan.',
              icon: Icons.receipt_long_outlined,
            ),
          ...orders.map((order) {
            final status = order.string('status');
            final next = widget.session.isSeller
                ? {'paid': 'purchased', 'purchased': 'delivered'}[status]
                : status == 'delivered'
                ? 'completed'
                : null;
            final actionLabel = {
              'purchased': 'Tandai sudah dibeli',
              'delivered': 'Tandai dikirim / diserahkan',
              'completed': 'Konfirmasi diterima & selesai',
            }[next];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pesanan #${order.number('id')}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        StatusLabel(status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(order.string('trip_name')),
                    Text(
                      widget.session.isSeller
                          ? 'Penitip · ${order.string('buyer_name')}'
                          : 'Jastiper · ${order.string('seller_name')}',
                    ),
                    const Divider(height: 28),
                    ...order
                        .rows('items')
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.number('quantity')} × ${item.string('name')}',
                                  ),
                                ),
                                Text(
                                  money(
                                    item.number('price') *
                                        item.number('quantity'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: 8),
                    Text(
                      'Total ${money(order.number('total'))}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        TextButton.icon(
                          onPressed: () => openPage(
                            context,
                            TrackingScreen(
                              session: widget.session,
                              tripId: order.number('trip_id'),
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Lacak trip'),
                        ),
                        if (next != null)
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (!await confirm(
                                      context,
                                      actionLabel!,
                                      next == 'completed'
                                          ? 'Pastikan barang sudah diterima. Saldo pesanan akan diteruskan ke jastiper.'
                                          : 'Perbarui status pesanan ini?',
                                    )) {
                                      return;
                                    }
                                    if (!mounted || !context.mounted) return;
                                    setState(() => _busy = true);
                                    if (await perform(context, () async {
                                      await widget.session.request(
                                        'order_status',
                                        {
                                          'id': order.number('id'),
                                          'status': next,
                                        },
                                      );
                                    })) {
                                      reload();
                                    }
                                    if (mounted) setState(() => _busy = false);
                                  },
                            child: Text(actionLabel!),
                          ),
                        if (!widget.session.isSeller &&
                            status == 'completed' &&
                            order['rating'] == null)
                          OutlinedButton(
                            onPressed: () async {
                              await openPage(
                                context,
                                ReviewEditor(
                                  session: widget.session,
                                  orderId: order.number('id'),
                                ),
                              );
                              reload();
                            },
                            child: const Text('Tulis ulasan'),
                          ),
                      ],
                    ),
                    if (order['rating'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '★ ${order.number('rating')}/5 · ${order.string('comment')}',
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}

class ReviewEditor extends StatefulWidget {
  const ReviewEditor({super.key, required this.session, required this.orderId});
  final Session session;
  final int orderId;
  @override
  State<ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<ReviewEditor> {
  final _comment = TextEditingController();
  final _form = GlobalKey<FormState>();
  int _rating = 5;
  bool _busy = false;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ulasan pesanan')),
    body: Form(
      key: _form,
      child: PageBody(
        children: [
          Wrap(
            children: List.generate(
              5,
              (index) => IconButton(
                tooltip: '${index + 1} bintang',
                onPressed: _busy
                    ? null
                    : () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: orange,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Input(_comment, 'Bagaimana pengalaman titipmu?', lines: 5),
          SubmitButton(
            busy: _busy,
            label: 'Kirim ulasan',
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              setState(() => _busy = true);
              final ok = await perform(context, () async {
                await widget.session.request('review', {
                  'order_id': widget.orderId,
                  'rating': _rating,
                  'comment': _comment.text,
                });
              });
              if (mounted && context.mounted) {
                setState(() => _busy = false);
                if (ok) Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
    ),
  );
}
