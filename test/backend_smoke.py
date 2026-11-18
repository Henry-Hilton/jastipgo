"""Run against a disposable database. Creates uniquely named test accounts/data.

python test/backend_smoke.py --url http://127.0.0.1:8091 --second-url http://127.0.0.1:8092
Use two PHP worker processes sharing the same test database for concurrency proof.
"""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
import json
import struct
import threading
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zlib


class Client:
    def __init__(self, url, role='penitip'):
        self.url = url
        self.role = role
        self.token = ''

    def call(self, action, expected=200, **values):
        request = urllib.request.Request(
            self.url + ('/uploadimage.php' if action == 'upload' else '/api.php'),
            json.dumps({'action': action, **values}).encode(),
            {'Content-Type': 'application/json', 'X-Role': self.role,
             'Authorization': 'Bearer ' + self.token},
        )
        try:
            response = urllib.request.urlopen(request, timeout=40)
        except urllib.error.HTTPError as error:
            response = error
        body = json.load(response)
        assert response.code == expected, (action, response.code, body)
        if expected != 200:
            return body
        assert body['result'] == 'success', body
        return body['data']

    def register(self, name, suffix):
        result = self.call('register', name=name, email=f'{suffix}@example.com', password='TestPassword123!')
        self.token = result['token']
        return result['user']


def png():
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    image = b'\x89PNG\r\n\x1a\n'
    image += chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
    image += chunk(b'IDAT', zlib.compress(b'\x00\x18\x77\x6c'))
    image += chunk(b'IEND', b'')
    return base64.b64encode(image).decode()


def run(url, second_url):
    suffix = uuid.uuid4().hex
    seller = Client(url, 'jastiper')
    buyer = Client(url)
    rival = Client(second_url)
    owner = seller.register('Jastiper Test', 'seller-' + suffix)
    buyer.register('Penitip Test', 'buyer-' + suffix)
    rival.register('Penitip Rival', 'rival-' + suffix)
    seller.call('login', expected=401, email='seller-' + suffix + '@example.com', password='incorrect')
    Client(url).call('me', expected=401)
    buyer.call('save_trip', expected=403)
    seller.call('save_trip', expected=422, name='Invalid', destination='Tokyo', departure='2026-02-30', return_date='2026-03-01')
    trip = seller.call('save_trip', name='Tokyo test ' + suffix, destination='Tokyo',
                       departure=date.today().isoformat(), return_date=(date.today() + timedelta(days=3)).isoformat())['id']
    buyer.call('save_trip', expected=403, id=trip)
    seller.call('upload', expected=422, image=base64.b64encode(b'<?php echo 1;?>').decode())
    photo = seller.call('upload', image=png())['path']
    assert photo.startswith('images/' + str(owner['id']) + '/') and photo.endswith('.png')
    with urllib.request.urlopen(url + '/image.php?path=' + urllib.parse.quote(photo)) as response:
        assert response.headers['Access-Control-Allow-Origin'] == '*'
        assert response.read(8) == b'\x89PNG\r\n\x1a\n'
    product = seller.call('save_product', trip_id=trip, name='Tokyo Banana', description='Test product',
                          price=150000, stock=3, photo=photo, category_ids=[1, 2])['id']
    buyer.call('save_product', expected=403, trip_id=trip)
    results = buyer.call('catalog', name='Tokyo Banana', destination=suffix, category_id=2)
    assert len(results) == 1 and len(results[0]['categories']) == 2
    buyer.call('favorite', product_id=product, enabled=True)
    assert any(p['id'] == product for p in buyer.call('catalog', favorites=True))
    buyer.call('request', trip_id=trip, name='Matcha', description='One matcha snack')
    request = seller.call('trip', id=trip)['requests'][0]
    seller.call('review_request', id=request['id'], approve=True, price=50000, stock=2, photo=photo, category_ids=[1])
    seller.call('review_request', expected=422, id=request['id'], approve=True, price=50000, stock=2, photo=photo, category_ids=[1])
    assert buyer.call('trip', id=trip)['requests'][0]['status'] == 'approved'
    buyer.call('cart_set', product_id=product, quantity=2)
    buyer.call('checkout', expected=422, operation_key='insufficient-balance')
    assert int(buyer.call('product', id=product)['stock']) == 3
    assert len(buyer.call('cart')) == 1
    assert int(buyer.call('wallet')['balance']) == 0
    buyer.call('topup', amount=1000000, operation_key='topup-test')
    buyer.call('topup', amount=1000000, operation_key='topup-test')
    buyer.call('topup', expected=422, amount=2000000, operation_key='topup-test')
    assert int(buyer.call('wallet')['balance']) == 1000000
    buyer.call('cart_set', product_id=product, quantity=2)
    result = buyer.call('checkout', operation_key='checkout-test')
    assert buyer.call('checkout', operation_key='checkout-test') == result
    assert buyer.call('cart') == []
    assert int(buyer.call('wallet')['balance']) == 700000
    assert int(seller.call('wallet')['balance']) == 0
    assert int(buyer.call('product', id=product)['stock']) == 1
    order = buyer.call('orders')[0]
    buyer.call('order_status', expected=422, id=order['id'], status='completed')
    rival.call('order_status', expected=403, id=order['id'], status='completed')
    seller.call('order_status', id=order['id'], status='purchased')
    seller.call('order_status', id=order['id'], status='delivered')
    buyer.call('order_status', id=order['id'], status='completed')
    buyer.call('order_status', id=order['id'], status='completed')
    assert int(seller.call('wallet')['balance']) == 300000
    buyer.call('review', order_id=order['id'], rating=5, comment='Great trip')
    buyer.call('review', expected=422, order_id=order['id'], rating=5, comment='Duplicate')
    assert len(buyer.call('product', id=product)['reviews']) == 1
    seller.call('trip_status', id=trip, status='live')
    seller.call('checkin', trip_id=trip, latitude=-7.32, longitude=112.77, accuracy=12,
                note='Shop check-in', photo=photo)
    assert len(buyer.call('trip', id=trip)['checkins']) == 1
    seller.call('checkin', expected=422, trip_id=trip, latitude=1000, longitude=112, accuracy=1, note='Invalid', photo=photo)
    assert len(buyer.call('inbox')) >= 3
    buyer.call('read_inbox')
    assert all(int(item['is_read']) == 1 for item in buyer.call('inbox'))

    # Two independent PHP processes race to buy the final unit.
    rival.call('topup', amount=500000, operation_key='rival-topup')
    buyer.call('cart_set', product_id=product, quantity=1)
    rival.call('cart_set', product_id=product, quantity=1)
    barrier = threading.Barrier(2)

    def compete(client):
        barrier.wait()
        try:
            client.call('checkout', operation_key='race')
            return 'success'
        except AssertionError as error:
            assert error.args[0][1] == 422, error
            return 'stock rejected'

    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = list(pool.map(compete, [buyer, rival]))
    assert sorted(outcomes) == ['stock rejected', 'success'], outcomes
    assert int(buyer.call('product', id=product)['stock']) == 0
    total_balances = sum(int(client.call('wallet')['balance']) for client in [seller, buyer, rival])
    assert total_balances == 1350000  # 1.5m top-up, 150k still held for the second order.
    summary = seller.call('trip', id=trip)['summary']
    assert sum(int(item['quantity']) for item in summary) == 3
    seller.call('trip_status', id=trip, status='finished')
    assert not buyer.call('catalog', destination=suffix)
    seller.call('checkin', expected=422, trip_id=trip, latitude=-7, longitude=112, accuracy=1, note='Late', photo=photo)
    buyer.call('logout')
    buyer.call('me', expected=401)
    print('PASS: auth, roles, validation, images, filters, categories, requests, favorites, cart,')
    print('top-up/checkout/settlement idempotency, reviews, GPS, inbox, ownership, concurrent stock, balance conservation.')
    return suffix


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', default='http://127.0.0.1:8091')
    parser.add_argument('--second-url', default='http://127.0.0.1:8092')
    args = parser.parse_args()
    run(args.url, args.second_url)
