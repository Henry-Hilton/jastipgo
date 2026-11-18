import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'widgets.dart';
import 'catalog.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) => DataView(
    load: () => session.request('trips', {'mine': session.isSeller}),
    builder: (data, reload) {
      final trips = records(data);
      return PageBody(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.isSeller ? 'Trip saya' : 'Jelajahi trip',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (session.isSeller)
                FilledButton.icon(
                  onPressed: () async {
                    await openPage(context, TripEditor(session: session));
                    reload();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Buka trip'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (trips.isEmpty)
            EmptyState(
              session.isSeller
                  ? 'Buka trip pertama untuk mulai menerima titipan.'
                  : 'Belum ada trip aktif.',
            ),
          ...trips.map(
            (trip) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const Icon(Icons.flight_takeoff, color: teal),
                title: Text(
                  trip.string('name'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.string('destination')),
                    const SizedBox(height: 6),
                    Text(
                      '${trip.string('departure')} — ${trip.string('return_date')}',
                    ),
                    StatusLabel(trip.string('status')),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await openPage(
                    context,
                    TripScreen(session: session, id: trip.number('id')),
                  );
                  reload();
                },
              ),
            ),
          ),
        ],
      );
    },
  );
}

class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.session, required this.id});
  final Session session;
  final int id;
  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail trip')),
    body: DataView(
      load: () => widget.session.request('trip', {'id': widget.id}),
      builder: (value, reload) {
        final trip = value as Json;
        final own =
            trip.number('owner_id') == widget.session.userId &&
            widget.session.isSeller;
        final active = ['open', 'live'].contains(trip.string('status'));
        Future<void> edit(Widget page) async {
          await openPage(context, page);
          reload();
        }

        return PageBody(
          children: [
            StatusLabel(trip.string('status')),
            const SizedBox(height: 12),
            Text(
              trip.string('name'),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${trip.string('destination')} · ${trip.string('owner_name')}',
              style: const TextStyle(fontSize: 18, color: teal),
            ),
            const SizedBox(height: 8),
            Text('${trip.string('departure')} — ${trip.string('return_date')}'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => edit(
                    TrackingScreen(session: widget.session, tripId: widget.id),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Lacak trip'),
                ),
                if (own && active) ...[
                  OutlinedButton.icon(
                    onPressed: () =>
                        edit(TripEditor(session: widget.session, trip: trip)),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit trip'),
                  ),
                  FilledButton.icon(
                    onPressed: () => edit(
                      ProductEditor(session: widget.session, tripId: widget.id),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah barang'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final next = trip.string('status') == 'open'
                                ? 'live'
                                : 'finished';
                            if (!await confirm(
                              context,
                              'Ubah status trip?',
                              next == 'live'
                                  ? 'Mulai perjalanan sesuai tanggal trip.'
                                  : 'Tutup katalog trip ini. Pesanan yang berjalan tetap perlu diselesaikan.',
                            )) {
                              return;
                            }
                            if (!mounted || !context.mounted) return;
                            setState(() => _busy = true);
                            if (await perform(context, () async {
                              await widget.session.request('trip_status', {
                                'id': widget.id,
                                'status': next,
                              });
                            })) {
                              reload();
                            }
                            if (mounted) setState(() => _busy = false);
                          },
                    child: Text(
                      trip.string('status') == 'open'
                          ? 'Mulai live trip'
                          : 'Selesaikan trip',
                    ),
                  ),
                  if (trip.string('status') == 'live')
                    FilledButton.icon(
                      onPressed: () => edit(
                        CheckinEditor(
                          session: widget.session,
                          tripId: widget.id,
                        ),
                      ),
                      icon: const Icon(Icons.my_location),
                      label: const Text('Check-in lokasi saat ini'),
                    ),
                ],
                if (!widget.session.isSeller &&
                    trip.number('owner_id') != widget.session.userId &&
                    active)
                  FilledButton.icon(
                    onPressed: () => edit(
                      RequestEditor(session: widget.session, tripId: widget.id),
                    ),
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Request barang'),
                  ),
              ],
            ),
            const Divider(height: 40),
            Text('Katalog trip', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (trip.rows('products').isEmpty)
              const EmptyState('Belum ada barang di trip ini.'),
            if (own)
              ...trip
                  .rows('products')
                  .map(
                    (product) => Card(
                      child: ListTile(
                        title: Text(product.string('name')),
                        subtitle: Text(
                          '${money(product.number('price'))} · Stok ${product.number('stock')}',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => edit(
                          ProductEditor(
                            session: widget.session,
                            tripId: widget.id,
                            product: product,
                          ),
                        ),
                      ),
                    ),
                  ),
            if (!own)
              ProductGrid(
                session: widget.session,
                products: trip.rows('products'),
                onReturn: reload,
              ),
            const Divider(height: 40),
            Text(
              'Request barang',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (trip.rows('requests').isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Belum ada request.'),
              ),
            ...trip
                .rows('requests')
                .map(
                  (request) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.string('name'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(request.string('description')),
                          Text('Dari ${request.string('buyer_name')}'),
                          StatusLabel(request.string('status')),
                          if (own &&
                              active &&
                              request.string('status') == 'pending')
                            Wrap(
                              spacing: 12,
                              children: [
                                TextButton(
                                  onPressed: () => edit(
                                    ProductEditor(
                                      session: widget.session,
                                      tripId: widget.id,
                                      request: request,
                                    ),
                                  ),
                                  child: const Text('Setujui & buat barang'),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          setState(() => _busy = true);
                                          if (await perform(context, () async {
                                            await widget.session.request(
                                              'review_request',
                                              {
                                                'id': request.number('id'),
                                                'approve': false,
                                              },
                                            );
                                          })) {
                                            reload();
                                          }
                                          if (mounted && context.mounted) {
                                            setState(() => _busy = false);
                                          }
                                        },
                                  child: const Text('Tolak'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            if (own) ...[
              const Divider(height: 40),
              Text(
                'Ringkasan belanja',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (trip.rows('summary').isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Belum ada pesanan.'),
                ),
              ...trip
                  .rows('summary')
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.string('name')),
                      subtitle: Text('${item.number('quantity')} barang'),
                      trailing: Text(money(item.number('total'))),
                    ),
                  ),
            ],
          ],
        );
      },
    ),
  );
}

class TripEditor extends StatefulWidget {
  const TripEditor({super.key, required this.session, this.trip});
  final Session session;
  final Json? trip;
  @override
  State<TripEditor> createState() => _TripEditorState();
}

class _TripEditorState extends State<TripEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.trip?.string('name'));
  late final _destination = TextEditingController(
    text: widget.trip?.string('destination'),
  );
  late final _departure = TextEditingController(
    text: widget.trip?.string('departure'),
  );
  late final _return = TextEditingController(
    text: widget.trip?.string('return_date'),
  );
  bool _busy = false;
  Future<void> _pick(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) controller.text = date.toIso8601String().substring(0, 10);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_return.text.compareTo(_departure.text) < 0) {
      showMessage(context, 'Tanggal kembali harus setelah tanggal berangkat.');
      return;
    }
    setState(() => _busy = true);
    final ok = await perform(context, () async {
      await widget.session.request('save_trip', {
        if (widget.trip != null) 'id': widget.trip!.number('id'),
        'name': _name.text,
        'destination': _destination.text,
        'departure': _departure.text,
        'return_date': _return.text,
      });
    });
    if (mounted && context.mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _destination, _departure, _return]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.trip == null ? 'Buka trip' : 'Edit trip'),
    ),
    body: Form(
      key: _form,
      child: PageBody(
        children: [
          Input(_name, 'Nama trip'),
          Input(_destination, 'Destinasi'),
          for (final entry in {
            _departure: 'Tanggal berangkat',
            _return: 'Tanggal kembali',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: entry.key,
                readOnly: true,
                validator: requiredText,
                onTap: () => _pick(entry.key),
                decoration: InputDecoration(
                  labelText: entry.value,
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
            ),
          SubmitButton(busy: _busy, onPressed: _submit, label: 'Simpan trip'),
        ],
      ),
    ),
  );
}

Future<String?> pickAndUpload(
  BuildContext context,
  Session session, {
  bool selfie = false,
}) async {
  ImageSource? source;
  if (selfie) {
    source = ImageSource.camera;
  } else {
    source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
  if (source == null) return null;
  if (selfie &&
      !kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform)) {
    throw const ApiException(
      'Gunakan ponsel atau browser dengan kamera untuk selfie check-in.',
    );
  }
  final image = await ImagePicker().pickImage(
    source: source,
    preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 80,
  );
  if (image == null) return null;
  final bytes = await image.readAsBytes();
  if (bytes.length > 6000000) throw const ApiException('Foto maksimal 6 MB.');
  final result =
      await session.request('upload', {'image': base64Encode(bytes)}) as Map;
  return result['path'] as String;
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({
    super.key,
    required this.session,
    required this.tripId,
    this.product,
    this.request,
  });
  final Session session;
  final int tripId;
  final Json? product;
  final Json? request;
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: (widget.product ?? widget.request)?.string('name'),
  );
  late final _description = TextEditingController(
    text: (widget.product ?? widget.request)?.string('description'),
  );
  late final _price = TextEditingController(
    text: widget.product?.string('price'),
  );
  late final _stock = TextEditingController(
    text: widget.product?.string('stock'),
  );
  late String _photo = widget.product?.string('photo') ?? '';
  late final Set<int> _categories =
      widget.product?.rows('categories').map((c) => c.number('id')).toSet() ??
      {};
  bool _busy = false;
  Future<void> _upload() async {
    setState(() => _busy = true);
    await perform(context, () async {
      final path = await pickAndUpload(context, widget.session);
      if (path != null && mounted) setState(() => _photo = path);
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_photo.isEmpty || _categories.isEmpty) {
      showMessage(context, 'Unggah foto dan pilih minimal satu kategori.');
      return;
    }
    setState(() => _busy = true);
    final ok = await perform(context, () async {
      await widget.session.request(
        widget.request == null ? 'save_product' : 'review_request',
        {
          'trip_id': widget.tripId,
          if (widget.product != null) 'id': widget.product!.number('id'),
          if (widget.request != null) ...{
            'id': widget.request!.number('id'),
            'approve': true,
          },
          'name': _name.text,
          'description': _description.text,
          'price': int.parse(_price.text),
          'stock': int.parse(_stock.text),
          'photo': _photo,
          'category_ids': _categories.toList(),
        },
      );
    });
    if (mounted && context.mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _description, _price, _stock]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.request != null
            ? 'Setujui request'
            : widget.product != null
            ? 'Edit barang'
            : 'Tambah barang',
      ),
    ),
    body: DataView(
      load: () => widget.session.request('categories'),
      builder: (data, reload) => Form(
        key: _form,
        child: PageBody(
          children: [
            if (_photo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Photo(widget.session.photo(_photo), height: 220),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _upload,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Pilih foto barang'),
            ),
            const SizedBox(height: 20),
            if (widget.request == null) ...[
              Input(_name, 'Nama barang'),
              Input(_description, 'Deskripsi', lines: 4),
            ] else ...[
              Text(_name.text, style: Theme.of(context).textTheme.titleLarge),
              Text(_description.text),
              const SizedBox(height: 20),
            ],
            Input(
              _price,
              'Harga (Rp)',
              number: true,
              validator: positiveNumber,
            ),
            Input(
              _stock,
              'Stok tersedia',
              number: true,
              validator: (value) {
                final stock = int.tryParse(value ?? '');
                return stock == null || stock < (widget.request == null ? 0 : 1)
                    ? 'Masukkan stok yang valid'
                    : null;
              },
            ),
            const Text('Kategori (boleh lebih dari satu)'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: records(data)
                  .map(
                    (category) => FilterChip(
                      label: Text(category.string('name')),
                      selected: _categories.contains(category.number('id')),
                      onSelected: _busy
                          ? null
                          : (selected) => setState(() {
                              selected
                                  ? _categories.add(category.number('id'))
                                  : _categories.remove(category.number('id'));
                            }),
                    ),
                  )
                  .toList(),
            ),
            SubmitButton(
              busy: _busy,
              onPressed: _submit,
              label: widget.request == null
                  ? 'Simpan barang'
                  : 'Setujui & tayangkan di katalog',
            ),
          ],
        ),
      ),
    ),
  );
}

class RequestEditor extends StatefulWidget {
  const RequestEditor({super.key, required this.session, required this.tripId});
  final Session session;
  final int tripId;
  @override
  State<RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends State<RequestEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request barang')),
    body: Form(
      key: _form,
      child: PageBody(
        children: [
          Input(_name, 'Nama barang'),
          Input(
            _description,
            'Detail barang, varian, dan jumlah yang diinginkan',
            lines: 5,
          ),
          SubmitButton(
            busy: _busy,
            label: 'Kirim request',
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              setState(() => _busy = true);
              final ok = await perform(context, () async {
                await widget.session.request('request', {
                  'trip_id': widget.tripId,
                  'name': _name.text,
                  'description': _description.text,
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

class CheckinEditor extends StatefulWidget {
  const CheckinEditor({super.key, required this.session, required this.tripId});
  final Session session;
  final int tripId;
  @override
  State<CheckinEditor> createState() => _CheckinEditorState();
}

class _CheckinEditorState extends State<CheckinEditor> {
  final _note = TextEditingController();
  bool _busy = false;
  Future<void> _submit() async {
    if (_note.text.trim().isEmpty) {
      showMessage(context, 'Isi nama toko atau catatan lokasi.');
      return;
    }
    setState(() => _busy = true);
    final ok = await perform(context, () async {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ApiException('Aktifkan layanan lokasi perangkat.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiException(
          'Izin lokasi diperlukan. Aktifkan di pengaturan perangkat/browser.',
        );
      }
      if (!mounted || !context.mounted) return;
      final photo = await pickAndUpload(context, widget.session, selfie: true);
      if (photo == null) {
        throw const ApiException('Check-in dibatalkan. Selfie diperlukan.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (position.isMocked) {
        throw const ApiException('Gunakan lokasi GPS perangkat yang asli.');
      }
      await widget.session.request('checkin', {
        'trip_id': widget.tripId,
        'note': _note.text,
        'photo': photo,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      });
    });
    if (mounted && context.mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Check-in lokasi')),
    body: PageBody(
      children: [
        const Icon(Icons.my_location, size: 64, color: teal),
        const SizedBox(height: 24),
        const Text(
          'Ambil selfie di lokasi toko. Posisi GPS saat ini akan disimpan bersama foto dan waktu check-in.',
        ),
        const SizedBox(height: 24),
        Input(_note, 'Nama toko / catatan lokasi'),
        SubmitButton(
          busy: _busy,
          onPressed: _submit,
          label: 'Ambil selfie & check-in',
        ),
      ],
    ),
  );
}

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    required this.session,
    required this.tripId,
  });
  final Session session;
  final int tripId;
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Timer? _timer;
  Json? _trip;
  String? _error;
  bool _loading = false;
  final _map = MapController();
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final result =
          await widget.session.request('trip', {'id': widget.tripId}) as Json;
      if (mounted && context.mounted) {
        setState(() {
          _trip = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkins = _trip?.rows('checkins') ?? [];
    final latest = checkins.isEmpty
        ? const LatLng(-7.2575, 112.7521)
        : LatLng(
            checkins.first.decimal('latitude'),
            checkins.first.decimal('longitude'),
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lacak trip'),
        actions: [
          IconButton(
            tooltip: 'Perbarui lokasi',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _trip == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_trip != null)
                  Text(
                    _trip!.string('name'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Riwayat check-in diperbarui otomatis setiap 15 detik.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: latest,
                        initialZoom: checkins.isEmpty ? 5 : 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'id.ac.ubaya.jastipgo',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: checkins.reversed
                                  .map(
                                    (p) => LatLng(
                                      p.decimal('latitude'),
                                      p.decimal('longitude'),
                                    ),
                                  )
                                  .toList(),
                              color: teal,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: checkins
                              .map(
                                (point) => Marker(
                                  point: LatLng(
                                    point.decimal('latitude'),
                                    point.decimal('longitude'),
                                  ),
                                  width: 44,
                                  height: 44,
                                  child: Tooltip(
                                    message:
                                        '${point.string('note')} · ${point.string('created_at')}',
                                    child: const Icon(
                                      Icons.location_on,
                                      color: orange,
                                      size: 42,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SimpleAttributionWidget(
                          source: Text('OpenStreetMap contributors'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (checkins.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _map.move(latest, 15),
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Ke lokasi terbaru'),
                  ),
                if (checkins.isEmpty)
                  const EmptyState('Belum ada check-in lokasi.'),
                ...checkins.map(
                  (point) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.string('note'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(point.string('created_at')),
                          Text(
                            '${point.decimal('latitude').toStringAsFixed(5)}, ${point.decimal('longitude').toStringAsFixed(5)} · ±${point.decimal('accuracy').round()} m',
                          ),
                          const SizedBox(height: 12),
                          Photo(
                            widget.session.photo(point.string('photo')),
                            height: 200,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
