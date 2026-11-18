import 'package:flutter/material.dart';

import 'data.dart';
import 'widgets.dart';
import 'trips.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.session});
  final Session session;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _name = TextEditingController();
  final _destination = TextEditingController();
  final _view = GlobalKey<DataViewState>();
  int? _category;
  bool _favorites = false;
  Future<Json> _load() async {
    final result = await Future.wait([
      widget.session.request('categories'),
      widget.session.request('catalog', {
        'name': _name.text,
        'destination': _destination.text,
        'category_id': _category,
        'favorites': _favorites,
      }),
    ]);
    return {'categories': result[0], 'products': result[1]};
  }

  @override
  void dispose() {
    _name.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DataView(
    key: _view,
    load: _load,
    builder: (value, reload) {
      final data = value as Json;
      final products = data.rows('products');
      return PageBody(
        children: [
          const SizedBox(height: 8),
          Text(
            'Mau titip apa\nhari ini?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Temukan barang dari trip yang sedang aktif.',
            style: TextStyle(color: teal, fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            onSubmitted: (_) => reload(),
            decoration: const InputDecoration(
              labelText: 'Nama barang',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destination,
            onSubmitted: (_) => reload(),
            decoration: const InputDecoration(
              labelText: 'Nama trip atau destinasi',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _category == null,
                onSelected: (_) {
                  _category = null;
                  reload();
                },
              ),
              ...data
                  .rows('categories')
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category.string('name')),
                      selected: _category == category.number('id'),
                      onSelected: (_) {
                        _category = category.number('id');
                        reload();
                      },
                    ),
                  ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  _favorites = !_favorites;
                  reload();
                },
                icon: Icon(_favorites ? Icons.favorite : Icons.favorite_border),
                label: const Text('Favorit saya'),
              ),
              const Spacer(),
              FilledButton.tonal(onPressed: reload, child: const Text('Cari')),
            ],
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const EmptyState(
              'Belum ada barang yang cocok.\nCoba filter lain atau jelajahi trip.',
            ),
          ProductGrid(
            session: widget.session,
            products: products,
            onReturn: reload,
          ),
        ],
      );
    },
  );
}

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.session,
    required this.products,
    required this.onReturn,
  });
  final Session session;
  final List<Json> products;
  final VoidCallback onReturn;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: constraints.maxWidth < 600 ? 2 : 3,
        mainAxisExtent: 174 + MediaQuery.textScalerOf(context).scale(142),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              await openPage(
                context,
                ProductScreen(session: session, id: product.number('id')),
              );
              onReturn();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Photo(session.photo(product.string('photo')), height: 150),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.string('trip_name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: teal, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.string('name'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        money(product.number('price')),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Stok ${product.number('stock')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.session, required this.id});
  final Session session;
  final int id;
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  int _quantity = 1;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail barang')),
    body: DataView(
      load: () => widget.session.request('product', {'id': widget.id}),
      builder: (value, reload) {
        final product = value as Json;
        final own = product.number('owner_id') == widget.session.userId;
        final active =
            ['open', 'live'].contains(product.string('trip_status')) &&
            product
                    .string('return_date')
                    .compareTo(
                      DateTime.now().toIso8601String().substring(0, 10),
                    ) >=
                0;
        return PageBody(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Photo(
                widget.session.photo(product.string('photo')),
                height: 320,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.string('name'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Simpan favorit',
                  icon: Icon(
                    product.number('favorite') == 1
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: orange,
                  ),
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          if (await perform(context, () async {
                            await widget.session.request('favorite', {
                              'product_id': widget.id,
                              'enabled': product.number('favorite') != 1,
                            });
                          })) {
                            reload();
                          }
                          if (mounted) setState(() => _busy = false);
                        },
                ),
              ],
            ),
            Text(
              money(product.number('price')),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: teal,
              ),
            ),
            const SizedBox(height: 16),
            Text(product.string('description')),
            const SizedBox(height: 16),
            Text(
              'Kategori · ${product.rows('categories').map((c) => c.string('name')).join(', ')}',
            ),
            Text('Stok tersedia · ${product.number('stock')}'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flight_takeoff),
              title: Text(product.string('trip_name')),
              subtitle: Text(
                '${product.string('destination')} · ${product.string('owner_name')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openPage(
                context,
                TripScreen(
                  session: widget.session,
                  id: product.number('trip_id'),
                ),
              ),
            ),
            if (!widget.session.isSeller &&
                !own &&
                active &&
                product.number('stock') > 0) ...[
              Row(
                children: [
                  IconButton(
                    tooltip: 'Kurangi',
                    onPressed: _quantity > 1 && !_busy
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$_quantity'),
                  IconButton(
                    tooltip: 'Tambah',
                    onPressed: _quantity < product.number('stock') && !_busy
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              SubmitButton(
                busy: _busy,
                label: 'Masukkan keranjang',
                onPressed: () async {
                  setState(() => _busy = true);
                  final ok = await perform(context, () async {
                    final cart = records(await widget.session.request('cart'));
                    final existing = cart.where(
                      (p) => p.number('id') == widget.id,
                    );
                    await widget.session.request('cart_set', {
                      'product_id': widget.id,
                      'quantity':
                          _quantity +
                          (existing.isEmpty
                              ? 0
                              : existing.first.number('quantity')),
                    });
                  });
                  if (mounted && context.mounted) {
                    setState(() => _busy = false);
                    if (ok) {
                      showMessage(context, 'Barang ditambahkan ke keranjang.');
                    }
                  }
                },
              ),
            ],
            const Divider(height: 40),
            Text(
              'Ulasan pembeli',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (product.rows('reviews').isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Belum ada ulasan.'),
              ),
            ...product
                .rows('reviews')
                .map(
                  (review) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${review.string('buyer_name')} · ${review.number('rating')}/5 ★',
                    ),
                    subtitle: Text(review.string('comment')),
                  ),
                ),
          ],
        );
      },
    ),
  );
}
