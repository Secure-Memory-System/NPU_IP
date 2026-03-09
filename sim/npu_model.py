import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
import numpy as np


# ==========================================
# 1. 하드웨어와 동일한 AI 모델 정의 (Twin Model)
# ==========================================
class HardwareNPUModel(nn.Module):
    def __init__(self):
        super(HardwareNPUModel, self).__init__()
        # Conv2D: 입력 1채널, 출력 1채널, 3x3 커널, 패딩 0 (Valid)
        self.conv = nn.Conv2d(in_channels=1, out_channels=1, kernel_size=3, padding=0)
        self.relu = nn.ReLU()
        # MaxPool: 2x2 커널, Stride 2
        self.pool = nn.MaxPool2d(kernel_size=2, stride=2)
        # Flatten 후 Dense: 28x28 이미지 -> Conv(26x26) -> Pool(13x13) = 169개 피처
        self.fc = nn.Linear(13 * 13, 10)

    def forward(self, x):
        x = self.conv(x)
        x = self.relu(x)
        x = self.pool(x)
        x = torch.flatten(x, 1)
        x = self.fc(x)
        return x


# ==========================================
# 2. MNIST 데이터셋 로드 및 학습
# ==========================================
print("--- 1. 데이터 로드 및 학습 시작 ---")
transform = transforms.Compose([transforms.ToTensor()])
train_dataset = datasets.MNIST(root='./data', train=True, download=True, transform=transform)
train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=64, shuffle=True)

model = HardwareNPUModel()
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.01)

# 하드웨어 검증을 위해 가볍게 1 Epoch만 학습합니다. (필요시 늘리세요!)
model.train()
for batch_idx, (data, target) in enumerate(train_loader):
    optimizer.zero_grad()
    output = model(data)
    loss = criterion(output, target)
    loss.backward()
    optimizer.step()

    if batch_idx % 200 == 0:
        print(f"Batch {batch_idx}/len(train_loader) Loss: {loss.item():.4f}")

print("--- 학습 완료! ---")

# ==========================================
# 3. 가중치 추출 및 8-bit 정수 양자화 (Quantization)
# ==========================================
print("\n--- 2. 가중치 양자화 및 추출 시작 ---")
# 모델 가중치 가져오기
conv_w = model.conv.weight.data.numpy().flatten()
conv_b = model.conv.bias.data.numpy()
fc_w = model.fc.weight.data.numpy()  # Shape: (10, 169)
fc_b = model.fc.bias.data.numpy()  # Shape: (10,)


# 양자화 함수 (Float -> 8-bit Signed Integer: -128 ~ 127)
def quantize_8bit(tensor, scale_factor=127.0):
    max_val = np.max(np.abs(tensor))
    if max_val == 0: return np.zeros_like(tensor, dtype=int)
    scale = scale_factor / max_val
    quantized = np.round(tensor * scale).astype(int)
    return np.clip(quantized, -128, 127)


# 16-bit 양자화 함수 (Bias용)
def quantize_16bit(tensor, scale_factor=32767.0):
    max_val = np.max(np.abs(tensor))
    if max_val == 0: return np.zeros_like(tensor, dtype=int)
    scale = scale_factor / max_val
    quantized = np.round(tensor * scale).astype(int)
    return np.clip(quantized, -32768, 32767)


q_conv_w = quantize_8bit(conv_w)
q_conv_b = quantize_16bit(conv_b)
q_fc_w = quantize_8bit(fc_w)
q_fc_b = quantize_16bit(fc_b)


# 2의 보수(Hex) 변환 함수 (Verilog 용)
def to_hex(val, bits):
    if val < 0: val = (1 << bits) + val
    return f"{val:0{bits // 4}x}"


# ==========================================
# 4. Verilog용 파일(.mem) 생성 및 출력
# ==========================================
print("\n--- 3. Verilog용 .mem 파일 생성 ---")

# 1) Conv 가중치 (9개) -> tb_npu_top.v 에 복사하기 위해 콘솔 출력
print("\n[Conv2D Weights (for tb_npu_top.v)]")
for i, w in enumerate(q_conv_w):
    print(f"w[{8 - i}] = 8'h{to_hex(w, 8)};  // 원본: {conv_w[i]:.4f}")
print(f"bias_in = 16'h{to_hex(q_conv_b[0], 16)};")

# 2) Dense 가중치 -> fc_weights.mem 파일로 저장
with open("fc_weights.mem", "w") as f:
    for class_idx in range(10):
        for feat_idx in range(169):
            hex_val = to_hex(q_fc_w[class_idx, feat_idx], 8)
            f.write(f"{hex_val}\n")
print("\n'fc_weights.mem' 파일 생성 완료! (1690줄)")

# 3) Dense 편향 -> fc_biases.mem 파일로 저장
with open("fc_biases.mem", "w") as f:
    for class_idx in range(10):
        hex_val = to_hex(q_fc_b[class_idx], 16)
        f.write(f"{hex_val}\n")
print("'fc_biases.mem' 파일 생성 완료! (10줄)")