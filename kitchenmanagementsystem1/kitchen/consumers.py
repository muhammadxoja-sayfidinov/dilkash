import json
from channels.generic.websocket import AsyncWebsocketConsumer

class KitchenConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_group_name = 'kitchen_orders'
        
        # Guruhga qo'shilish
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        
        await self.accept()
    
    async def disconnect(self, close_code):
        # Guruhdan chiqish
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
    
    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message = text_data_json['message']
        
        # Guruhga xabar yuborish
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'kitchen_message',
                'message': message
            }
        )
    
    async def kitchen_message(self, event):
        message = event['message']
        
        # WebSocket orqali xabar yuborish
        await self.send(text_data=json.dumps({
            'message': message
        }))
    
    async def order_update(self, event):
        # Buyurtma yangilanishi
        await self.send(text_data=json.dumps({
            'type': 'order_update',
            'order_id': event['order_id'],
            'status': event['status'],
            'old_status': event.get('old_status'),
            'message': event['message']
        }))
    
    async def product_update(self, event):
        # Mahsulot yangilanishi
        await self.send(text_data=json.dumps({
            'type': 'product_update',
            'product_id': event['product_id'],
            'is_available': event['is_available'],
            'message': event['message']
        }))
