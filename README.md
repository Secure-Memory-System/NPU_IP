# 🧠 MNIST NPU IP: AI-Powered Secure SoC Engine
> **Zynq SoC 기반의 지능형 무선 보안 통신 시스템을 위한 고성능 CNN 가속기**

<p align="left">
  <img src="https://img.shields.io/badge/Verilog-F34B7D?style=flat-square&logo=verilog&logoColor=white" />
  <img src="https://img.shields.io/badge/Vivado-FF6600?style=flat-square&logo=xilinx&logoColor=white" />
  <img src="https://img.shields.io/badge/PyTorch-EE4C2C?style=flat-square&logo=pytorch&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" />
</p>

본 프로젝트는 **Zynq SoC** 플랫폼에서 동작하는 지능형 보안 시스템의 핵심 코어입니다. 실시간 손글씨(MNIST) 인식을 통해 하드웨어 단에서 직접 데이터를 분류하고, 보안 모듈(AES 등)과의 긴밀한 연동을 지원하도록 설계되었습니다.

---

## ✨ 핵심 기능 (Key Features)

* **⚡ 고속 하드웨어 파이프라인**: Conv2D, ReLU, Max Pooling, Dense 레이어를 RTL로 완전 병렬 구현
* **🛠️ SoC 최적화 인터페이스**: 
    * `AXI4-Lite (Slave)`: CPU 기반의 실시간 가중치(Weight) 및 시스템 설정 제어
    * `AXI4-Stream (Slave)`: DMA 연동을 통한 대용량 이미지 데이터의 고속 스트리밍 입력
    * `AXI4-Stream (Master)`: 연산 결과(Classification Result)를 다음 보안 모듈로 즉시 전송
* **📉 경량화 설계 (Quantization)**: 8-bit/16-bit 고정 소수점 연산을 적용하여 FPGA 리소스 점유율 최소화

---

## 🏗️ 시스템 아키텍처 (Architecture)

### **NPU Core Pipeline**
NPU는 데이터 흐름의 효율성을 위해 각 레이어가 파이프라인 구조로 연결되어 있습니다.

| 단계 | 모듈명 | 주요 역할 |
| :--- | :--- | :--- |
| **Input** | `line_buffer` | 3x3 윈도우 슬라이딩 및 라인 버퍼링 제어 |
| **Compute** | `universal_pe` | CNN 특징 추출 연산 및 ReLU 활성화 함수 처리 |
| **Reduce** | `max_pooling` | 특징 강화 및 데이터 압축 (2x2 Max Pool) |
| **Classify** | `flatten_dense` | 169개 특징 기반 최종 숫자(0-9) 판별 및 점수 비교 |
| **Wrapper** | `npu_axi_wrapper` | AXI 규격 호환 및 시스템 버스 통합 인터페이스 |

---

## 📂 프로젝트 구조 (Project Structure)

```bash
├── hdl/                # Verilog RTL 설계 소스
│   ├── npu_top.v       # NPU 시스템 최상위 모듈
│   ├── universal_pe.v  # 연산 가속 유닛 (PE)
│   ├── line_buffer.v   # 라인 버퍼 제어기
│   ├── max_pooling.v   # 맥스 풀링 유닛
│   ├── flatten_dense.v # 전결합층 및 분류기
│   └── npu_axi_wrapper.v # AXI IP 래퍼
├── python/             # AI 모델링 및 가중치 추출
│   ├── train.py        # PyTorch 학습 및 8-bit 양자화 스크립트
│   ├── fc_weights.mem  # Dense 레이어 가중치 데이터
│   └── test_image.mem  # 검증용 테스트 이미지 데이터
├── sim/                # 검증용 테스트벤치
│   └── tb_npu_top.v    # 통합 하드웨어 시뮬레이션 모델
└── README.md
