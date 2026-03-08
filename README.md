🚀 MNIST NPU IP: CNN Accelerator for Secure SoC본 프로젝트는 Zynq SoC 기반의 AI 기반 지능형 무선 보안 통신 시스템 개발의 일환으로 설계된 고성능 NPU(Neural Processing Unit) IP입니다. MNIST 손글씨 이미지를 실시간으로 분석하여 숫자를 판별하고, 보안 모듈(AES-128 등)로 결과 데이터를 전송하기 위한 최적화된 하드웨어 파이프라인을 제공합니다.🌟 Key FeaturesFull Hardware Pipeline: Conv2D, ReLU, Max Pooling, Flatten, Dense(FC) 레이어가 순수 Verilog(RTL)로 구현되었습니다. SoC Infrastructure Ready: Zynq PS 및 DMA와 완벽하게 연동될 수 있도록 AXI 인터페이스를 표준화하였습니다.AXI4-Lite (Slave): 해상도, 가중치, 시작 신호 제어용 레지스터 맵 제공.AXI4-Stream (Slave): DMA로부터의 고속 픽셀 스트림 입력.AXI4-Stream (Master): 최종 판별 결과(Digit)를 암호화 IP로 즉시 전송.Resource Optimized: 8-bit/16-bit 정수 연산(Fixed-point) 및 시퀀셜 MAC 구조를 통해 FPGA 리소스 사용량을 최소화했습니다. Verified with Golden Model: PyTorch로 학습된 AI 모델과 RTL 시뮬레이션 결과가 100% 일치함을 검증 완료했습니다. 🏗️ Hardware ArchitectureNPU 코어는 데이터 흐름의 효율성을 극대화하기 위해 모듈별로 독립적인 제어 로직을 가집니다.Core Modules모듈명설명주요 기능npu_controller시스템 전체 상태 제어FSM 기반 좌표 및 패딩 제어 로직 line_buffer슬라이딩 윈도우 생성3x3 컨볼루션 연산을 위한 라인 버퍼링 universal_pe특징 추출 (Convolution)MAC 연산 및 ReLU 활성화 함수 적용 max_pooling데이터 압축2x2 영역의 최댓값 추출을 통한 특징 강화 flatten_dense최종 숫자 판별특징맵 평탄화 및 169-to-10 전결합층 연산npu_axi_wrapper시스템 통합 껍데기AXI-Lite 및 AXI-Stream 프로토콜 변환📂 Project StructurePlaintext├── hdl/                # Verilog RTL Source Files
│   ├── npu_top.v       # NPU Core 최상위 모듈 [cite: 60-73]
│   ├── universal_pe.v  # 연산 유닛 (PE) 
│   ├── line_buffer.v   # 라인 버퍼 모듈 
│   ├── max_pooling.v   # 맥스 풀링 모듈 
│   ├── npu_controller.v# 컨트롤러 및 좌표 생성기 
│   └── npu_axi_wrapper.v# AXI 인터페이스 래퍼
├── sim/                # 시뮬레이션 및 테스트벤치
│   └── tb_npu_top.v    # 통합 하드웨어 검증 모델 
├── python/             # AI 모델링 및 검증 스크립트
│   ├── train.py        # PyTorch 학습 및 양자화 코드
│   ├── fc_weights.mem  # 추출된 Dense 레이어 가중치
│   └── test_image.mem  # 검증용 실제 숫자 이미지 데이터
└── README.md
🛠️ Verification Result (Simulation)Vivado XSim을 통한 최종 검증 결과입니다.  실제 MNIST 숫자 '7' 데이터를 입력했을 때, 하드웨어가 정확하게 숫자를 판별해 내는 것을 확인할 수 있습니다.Plaintext--- Input Finished (done_tick) ---
Time: 25055000 | *** NPU Final Recognized Digit: 7 ***
--- Simulation Finished ---
👤 Authoreunjounglee (GitHub)Expertise: 4년간의 반도체 소재 및 분석 경험 기반의 SoC 설계 및 임베디드 시스템 개발Current Projects: AI 기반 지능형 보안 통신 시스템 및 FPGA 기반 가속기 설계
