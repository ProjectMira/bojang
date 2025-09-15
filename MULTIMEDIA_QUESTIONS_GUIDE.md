# Multimedia Questions Guide

This document explains the new question types and media integration for the Bojang Tibetan Learning App.

## Updated Database Schema

### New Question Types

The following question types have been added to support multimedia content:

- `AUDIO_TO_TEXT` - Listen to audio and choose text answer
- `TEXT_TO_AUDIO` - Read text and choose correct audio pronunciation  
- `IMAGE_TO_TEXT` - Look at image and choose text answer
- `TEXT_TO_IMAGE` - Read text and choose matching image
- `AUDIO_MULTIPLE_CHOICE` - Audio question with multiple text choices
- `IMAGE_MULTIPLE_CHOICE` - Image question with multiple text choices

### Schema Changes

#### Question Model
- Added `questionImageUrl` field for image-based questions
- Made `questionText` optional (for pure audio/image questions)

#### QuestionOption Model
- Added `optionImageUrl` field for image-based answer options
- Added `optionAudioUrl` field for audio-based answer options
- Made `optionText` optional (for pure audio/image options)

## S3 Bucket Structure

### Recommended Bucket Setup

#### Audio Bucket: `bojang-audio-bucket`
```
bojang-audio-bucket/
├── animals/
│   ├── khyi_dog.mp3
│   ├── zhimi_cat.mp3
│   ├── stag_tiger.mp3
│   └── ...
├── food/
│   ├── momo.mp3
│   ├── thukpa.mp3
│   ├── butter-tea-request.mp3
│   └── ...
├── greetings/
│   ├── tashi-delek.mp3
│   ├── thugs-che.mp3
│   └── ...
└── phrases/
    ├── butter-tea-request.mp3
    ├── sweet-tea-request.mp3
    └── ...
```

#### Images Bucket: `bojang-images-bucket`
```
bojang-images-bucket/
├── body-parts/
│   ├── eye.jpg
│   ├── hand.jpg
│   ├── nose.jpg
│   └── ...
├── food/
│   ├── momo.jpg
│   ├── butter-tea.jpg
│   ├── tsampa.jpg
│   └── ...
├── animals/
│   ├── dog.jpg
│   ├── cat.jpg
│   ├── tiger.jpg
│   └── ...
└── household/
    ├── table.jpg
    ├── chair.jpg
    └── ...
```

### S3 Configuration

#### Bucket Policy for Public Read Access
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::bojang-*-bucket/*"
        }
    ]
}
```

#### CORS Configuration
```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": []
    }
]
```

## Sample Question Data

### Audio Questions Example
```json
{
  "type": "audio_multiple_choice",
  "questionType": "AUDIO_TO_TEXT",
  "questionAudioUrl": "https://bojang-audio-bucket.s3.amazonaws.com/animals/khyi_dog.mp3",
  "questionText": "Listen to the Tibetan word. What animal is this?",
  "options": [
    { "optionText": "Dog", "optionTextTibetan": "ཁྱི" },
    { "optionText": "Cat", "optionTextTibetan": "ཞི་མི" },
    { "optionText": "Horse", "optionTextTibetan": "རྟ" },
    { "optionText": "Bird", "optionTextTibetan": "བྱ" }
  ],
  "correctAnswerIndex": 0
}
```

### Image Questions Example
```json
{
  "type": "image_multiple_choice",
  "questionType": "IMAGE_TO_TEXT",
  "questionImageUrl": "https://bojang-images-bucket.s3.amazonaws.com/body-parts/eye.jpg",
  "questionText": "What body part is shown in the image?",
  "options": [
    { "optionText": "Eye", "optionTextTibetan": "མིག" },
    { "optionText": "Nose", "optionTextTibetan": "སྣ" },
    { "optionText": "Ear", "optionTextTibetan": "རྣ་བ" },
    { "optionText": "Mouth", "optionTextTibetan": "ཁ" }
  ],
  "correctAnswerIndex": 0
}
```

## Implementation Notes

### Audio File Requirements
- Format: MP3 or WAV
- Quality: 128kbps minimum
- Length: 1-10 seconds for single words, up to 30 seconds for phrases
- Naming: Use descriptive names with underscores (e.g., `khyi_dog.mp3`)

### Image File Requirements
- Format: JPG or PNG
- Size: Maximum 500KB per image
- Dimensions: 800x600 recommended
- Quality: High quality for clear visibility
- Naming: Use descriptive names with hyphens (e.g., `butter-tea.jpg`)

### Frontend Integration
The app should handle these new question types by:
1. Detecting question type from `questionType` field
2. Loading appropriate media (audio/image) from S3 URLs
3. Rendering appropriate UI components for each type
4. Handling user interactions (audio playback, image display)

## Migration Steps

1. **Update Database**: Run Prisma migration to apply schema changes
2. **Create S3 Buckets**: Set up audio and images buckets with public read access
3. **Upload Media Files**: Organize and upload audio/image content
4. **Update Frontend**: Implement UI components for new question types
5. **Test**: Verify all media loads correctly and questions function properly

## Future Enhancements

- Video support for complex cultural explanations
- Interactive pronunciation feedback using speech recognition
- Augmented reality for object identification
- Offline caching of media files for better performance
