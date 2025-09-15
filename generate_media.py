#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont
import wave
import struct

# Create placeholder images
def create_placeholder_image(text, filename, size=(800, 600)):
    img = Image.new('RGB', size, color='lightblue')
    draw = ImageDraw.Draw(img)
    
    # Try to use a larger font
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 60)
    except:
        try:
            font = ImageFont.truetype('/System/Library/Fonts/Arial.ttf', 60)
        except:
            font = ImageFont.load_default()
    
    # Calculate text position to center it
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    position = ((size[0] - text_width) // 2, (size[1] - text_height) // 2)
    
    draw.text(position, text, fill='darkblue', font=font)
    img.save(filename)
    print(f'Created: {filename}')

# Create placeholder audio files (1 second of silence)
def create_placeholder_audio(filename, duration=1.0):
    sample_rate = 44100
    frames = int(duration * sample_rate)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # mono
        wav_file.setsampwidth(2)  # 2 bytes per sample
        wav_file.setframerate(sample_rate)
        
        # Generate silence
        for _ in range(frames):
            wav_file.writeframes(struct.pack('<h', 0))
    print(f'Created: {filename}')

# Body parts images
body_parts = [
    ('Eye', 'assets/images/body-parts/eye.jpg'),
    ('Hand', 'assets/images/body-parts/hand.jpg'),
    ('Head', 'assets/images/body-parts/head.jpg'),
    ('Nose', 'assets/images/body-parts/nose.jpg'),
    ('Foot', 'assets/images/body-parts/foot.jpg'),
    ('Mouth', 'assets/images/body-parts/mouth.jpg'),
    ('Ear', 'assets/images/body-parts/ear.jpg'),
    ('Arm', 'assets/images/body-parts/arm.jpg'),
    ('Leg', 'assets/images/body-parts/leg.jpg')
]

print("Creating body parts images...")
for name, path in body_parts:
    create_placeholder_image(name, path)

# Food images  
food_items = [
    ('Momo', 'assets/images/food/momo.jpg'),
    ('Butter Tea', 'assets/images/food/butter-tea.jpg'),
    ('Tsampa', 'assets/images/food/tsampa.jpg'),
    ('Thukpa', 'assets/images/food/thukpa.jpg'),
    ('Shapale', 'assets/images/food/shapale.jpg'),
    ('Sweet Tea', 'assets/images/food/sweet-tea.jpg'),
    ('Yak Meat', 'assets/images/food/yak-meat.jpg'),
    ('Milk Tea', 'assets/images/food/milk-tea.jpg'),
    ('Green Tea', 'assets/images/food/green-tea.jpg')
]

print("Creating food images...")
for name, path in food_items:
    create_placeholder_image(name, path)

# Animal images
animals = [
    ('Dog', 'assets/images/animals/dog.jpg'),
    ('Cat', 'assets/images/animals/cat.jpg'),
    ('Horse', 'assets/images/animals/horse.jpg'),
    ('Tiger', 'assets/images/animals/tiger.jpg'),
    ('Yak', 'assets/images/animals/yak.jpg'),
    ('Bird', 'assets/images/animals/bird.jpg'),
    ('Lion', 'assets/images/animals/lion.jpg'),
    ('Bear', 'assets/images/animals/bear.jpg'),
    ('Wolf', 'assets/images/animals/wolf.jpg')
]

print("Creating animal images...")
for name, path in animals:
    create_placeholder_image(name, path)

# Audio files for animals
animal_audio = [
    'assets/audio/animals/khyi_dog.wav',
    'assets/audio/animals/zhimi_cat.wav',
    'assets/audio/animals/rta_horse.wav',
    'assets/audio/animals/stag_tiger.wav',
    'assets/audio/animals/sengge_lion.wav',
    'assets/audio/animals/dom_bear.wav',
    'assets/audio/animals/spyang_wolf.wav',
    'assets/audio/animals/glag_yak.wav'
]

print("Creating animal audio files...")
for audio_path in animal_audio:
    create_placeholder_audio(audio_path)

# Audio files for food
food_audio = [
    'assets/audio/food/momo.wav',
    'assets/audio/food/thukpa.wav',
    'assets/audio/food/tsampa.wav',
    'assets/audio/food/shapale.wav',
    'assets/audio/food/gundruk.wav'
]

print("Creating food audio files...")
for audio_path in food_audio:
    create_placeholder_audio(audio_path)

# Audio files for phrases
phrase_audio = [
    'assets/audio/phrases/butter-tea-request.wav',
    'assets/audio/phrases/sweet-tea-request.wav',
    'assets/audio/phrases/water-request.wav',
    'assets/audio/phrases/milk-request.wav'
]

print("Creating phrase audio files...")
for audio_path in phrase_audio:
    create_placeholder_audio(audio_path)

# Audio files for greetings
greeting_audio = [
    'assets/audio/greetings/tashi-delek.wav',
    'assets/audio/greetings/thugs-che.wav',
    'assets/audio/greetings/goodbye.wav'
]

print("Creating greeting audio files...")
for audio_path in greeting_audio:
    create_placeholder_audio(audio_path)

print('All placeholder media files created successfully!')
