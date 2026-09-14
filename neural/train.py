"""Train a coordinate MLP; export the exact integer model used by the RTL.

The target is an analytic interference field, not a photograph or lookup table.
Its formula is only used during training/evaluation, never in inference firmware.
"""
from pathlib import Path
import argparse
import json
import math
import time

import numpy as np
import torch
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def target_image(size):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / (size - 1)
    u, v = x * 2 - 1, y * 2 - 1
    radius = np.sqrt((u + .22) ** 2 + (v - .10) ** 2 + .025)
    wave = .5 + .5 * np.sin(8.5 * radius - 3.0 * u + 1.8 * v)
    ribbon = np.exp(-14 * (v - .36 * np.sin(3.5 * u)) ** 2)
    glow = np.exp(-2.0 * ((u - .3) ** 2 + (v + .2) ** 2))
    rgb = np.stack((.08 + .68 * wave * glow + .23 * ribbon,
                    .06 + .56 * ribbon + .27 * (1 - wave) * glow,
                    .14 + .58 * (1 - wave) + .20 * ribbon), axis=-1)
    return np.clip(rgb, 0, 1)


def integer_render(model, size):
    y, x = np.mgrid[0:size, 0:size]
    a = np.stack((np.rint(x * 127 / (size - 1)),
                  np.rint(y * 127 / (size - 1))), -1).reshape(-1, 2).astype(np.int64)
    for layer in model['layers']:
        a = (a @ np.array(layer['weights'], dtype=np.int64).T + layer['bias']) >> layer['shift']
        a = np.clip(a, 0 if layer['relu'] else -128, 127)
    return a.reshape(size, size, 3)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--steps', type=int, default=6000)
    parser.add_argument('--size', type=int, default=64)
    args = parser.parse_args()
    torch.manual_seed(19)
    torch.set_num_threads(4)
    np.random.seed(19)
    target = target_image(args.size)
    y, x = np.mgrid[0:args.size, 0:args.size]
    xy = np.stack((x, y), -1).reshape(-1, 2) / (args.size - 1)
    inputs = torch.tensor(np.rint(xy * 127) / 127, dtype=torch.float32)
    labels = torch.tensor(target.reshape(-1, 3), dtype=torch.float32)
    layers = torch.nn.ModuleList([torch.nn.Linear(a, b) for a, b in zip([2, 32, 32], [32, 32, 3])])
    optimizer = torch.optim.Adam(layers.parameters(), lr=.003)
    started = time.time()
    history = []

    def straight_round(value, floor=False):
        rounded = torch.floor(value) if floor else torch.round(value)
        return value + (rounded - value).detach()

    for step in range(args.steps):
        # Last half is quantization-aware: exact deployment rounding in forward.
        quantized = step >= args.steps // 2
        a = inputs
        for layer in layers:
            weight = layer.weight.clamp(-2, 127 / 64)
            bias = layer.bias.clamp(-32768 / (64 * 127), 32767 / (64 * 127))
            if quantized:
                weight = straight_round(weight * 64) / 64
                bias = straight_round(bias * 64 * 127) / (64 * 127)
            a = torch.nn.functional.linear(a, weight, bias)
            if quantized:
                a = straight_round(a * 127, floor=True) / 127
            a = a.clamp(0, 1)
        loss = ((a - labels) ** 2).mean()
        optimizer.zero_grad(); loss.backward(); optimizer.step()
        if step % 500 == 0 or step == args.steps - 1:
            item = {'step': step, 'mse': loss.item(), 'quantization_aware': quantized}
            history.append(item)
            print(json.dumps(item), flush=True)
    exported = []
    for layer in layers:
        exported.append({
            'weights': torch.round(layer.weight.detach().clamp(-2, 127 / 64) * 64).int().tolist(),
            'bias': torch.round(layer.bias.detach().clamp(-32768 / 8128, 32767 / 8128) * 8128).int().tolist(),
            'shift': 6, 'relu': True})
    model = {'schema': 1, 'name': 'Interference / coordinate MLP',
             'seed': 19, 'dimensions': [2, 32, 32, 3], 'input_scale': 127,
             'output_scale': 127, 'layers': exported,
             'training': {'steps': args.steps, 'size': args.size, 'optimizer': 'Adam',
                          'learning_rate': .003, 'torch': torch.__version__, 'history': history}}
    result = integer_render(model, args.size)
    mse = float(np.mean((result / 127 - target) ** 2))
    model['evaluation'] = {'size': args.size, 'mse': mse, 'psnr_db': -10 * math.log10(mse),
                           'training_seconds': time.time() - started}
    out = ROOT / 'neural' / 'assets'; out.mkdir(exist_ok=True)
    (out / 'model.json').write_text(json.dumps(model, indent=2) + '\n')
    Image.fromarray(np.rint(target * 255).astype(np.uint8)).save(out / 'target.png')
    Image.fromarray(np.rint(result * 255 / 127).astype(np.uint8)).save(out / 'integer-reference.png')
    print(json.dumps(model['evaluation']), flush=True)


if __name__ == '__main__':
    main()
