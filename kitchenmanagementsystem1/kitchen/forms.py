from django import forms
from .models import Product, Category

class ProductForm(forms.ModelForm):
    class Meta:
        model = Product
        fields = ['name', 'category', 'price', 'description', 'image', 'is_available', 'preparation_time']
        widgets = {
            'name': forms.TextInput(attrs={'class': 'form-input large-text', 'placeholder': 'Mahsulot nomi'}),
            'price': forms.NumberInput(attrs={'class': 'form-input large-text', 'placeholder': 'Narxi'}),
            'description': forms.Textarea(attrs={'class': 'form-textarea large-text', 'placeholder': 'Tavsif', 'rows': 3}),
            'preparation_time': forms.NumberInput(attrs={'class': 'form-input large-text', 'placeholder': 'Tayyorlash vaqti (daqiqa)'}),
            'category': forms.Select(attrs={'class': 'form-select large-text'}),
        }
