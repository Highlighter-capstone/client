
# Highlighter : YOLO 모델을 이용한 동영상 하이라이트 추출기


## 요약
---
코로나 사태가 회복면서 여행객의 수요가 늘었지만, 여행의 결과물인 사진 및 동영상, 특히, 동영상에 대한 관리 기능이 부족한 상황이다. 
동영상은 여행 중의 즐거운 순간들을 생동감 있게 표현해줄 수 있는 매체인데, 재생 시간이 너무 긴 경우에는 다 보지 못한다는 단점도 가지고 있다. 
이에 본 연구에서는 객체 인식 모델, 표정 인식 기술, 동영상 압축 기술을 사용하여 동영상의 내용 중 의미 있는 순간들을 기록한 영상 하이라이트를 제작하여
사용자가 편하게 관리 혹은 감상할 수 있는 모바일 애플리케이션을 제안한다.

## 프로젝트 구조
---
```
Front-end : Swift(iOS)
Back-end : Flask
Cloud : AWS S3
Library : OpenCV, Haarcascades, YOLO
```
## 시스템 구성도
---
![image](https://user-images.githubusercontent.com/29617557/171854630-1dc26314-e759-4ca0-908e-724f8f217cb5.jpeg)

## 시스템 시퀀스 다이어그램
---
![image](https://user-images.githubusercontent.com/29617557/171855643-6afd50c3-876b-47fa-895f-cbdf382a107d.png)


# YOLO
---
## Extract emotions with image and video

The software recognizes corresponding emotions in a person's face through videos, webcams, or images.  
 Based on OpenCV and haarcascade and deep learning.

![image](https://user-images.githubusercontent.com/29617557/171856516-fe7b7524-0f38-4593-85ee-cd9d8e39a01f.png)

## Installation

> Install required library modules using anaconda and pip

```
conda install tensorflow==2.1.0

conda install -c conda-forge opencv

keras is installed by anaconda Navigator.

pip install pandas

pip install matplotlib

pip install scipy==1.2.0

pip install h5py==2.10.0
```

## Train models

> fer2013.tar.gz file

- [다운로드](https://www.kaggle.com/c/challenges-in-representation-learning-facial-expression-recognition-challenge/data)

- Facial Emotion Recongintion in FER2013 Dataset Using Conv

- Download and extract this file to use

## implement

```python

python extract_emotions_by_image.py

```

1. The coordinate value of the person's bounding box and the image detected by the person are received through yolo.

2. Check the coordinate values and images to see if this person is smiling and having fun.

3. If the result is happy, return true.
