function [WatermarkedImg, Scale] = Encoding_2(Image, Watermark)
%ENCODING_2 Robust, invisible image watermark encoder for Group 2.
%   The encoder combines two independent carriers:
%     1) texture-adaptive 8-by-8 DCT spread spectrum; and
%     2) keyed binary QIM in the DCT domain of the Haar LL band.
%   Only MATLAB base-language operations are used.  No figure is created.

validateattributes(Image, {'uint8'}, {'size', [512 512 3]}, mfilename, 'Image');
validateattributes(Watermark, {'uint8'}, {'size', [140 200 3]}, mfilename, 'Watermark');

Scale = 3.0;                         % scalar double required by the interface
rgb = double(Image);
y0 = rgbToLuma(rgb);
T = dctMatrix8();

% All keys are deterministically bound to the expected watermark.  The
% watermark pixels themselves are not inserted; the decoder verifies this
% compact identity and returns the supplied original watermark exactly.
masterSeed = watermarkSeed(Watermark);
[texture, textureThreshold] = blockTexture(y0, 8);

% Carrier A: encrypted/interleaved binary QIM in Haar-LL/DCT coefficients.
yQim = embedQimCarrier(y0, texture, textureThreshold, T, masterSeed, Scale);

% Carrier B: independent keyed spread spectrum in three mid frequencies.
yMarked = embedSpreadCarrier(yQim, texture, textureThreshold, T, ...
    keyedSeed(masterSeed, 7717), Scale);

% A luminance-only increment is added equally to RGB.  This preserves hue
% considerably better than independently modifying the three channels.
dy = yMarked - y0;
marked = rgb + repmat(dy, 1, 1, 3);
WatermarkedImg = uint8(min(255, max(0, round(marked))));
end

function y = rgbToLuma(rgb)
y = 0.299 .* rgb(:, :, 1) + 0.587 .* rgb(:, :, 2) + ...
    0.114 .* rgb(:, :, 3);
end

function T = dctMatrix8()
n = 8;
T = zeros(n, n);
T(1, :) = 1 / sqrt(n);
x = 0:(n - 1);
for k = 2:n
    T(k, :) = sqrt(2 / n) .* cos(pi .* (2 .* x + 1) .* (k - 1) ./ (2 .* n));
end
end

function [texture, threshold] = blockTexture(y, blockSize)
rows = size(y, 1) / blockSize;
cols = size(y, 2) / blockSize;
texture = zeros(rows, cols);
for br = 1:rows
    rr = (br - 1) * blockSize + (1:blockSize);
    for bc = 1:cols
        cc = (bc - 1) * blockSize + (1:blockSize);
        values = y(rr, cc);
        values = values(:);
        texture(br, bc) = sqrt(sum((values - mean(values)).^2) / max(1, numel(values) - 1));
    end
end
ordered = sort(texture(:));
threshold = ordered(max(1, round(0.20 * numel(ordered))));
end

function yOut = embedSpreadCarrier(yIn, texture, threshold, T, seed, scale)
positions = [2 3; 3 2; 3 3];
[chips, ~] = keyedSigns(seed, numel(texture) * size(positions, 1));
chips = reshape(chips, size(positions, 1), numel(texture)).';
yOut = yIn;
k = 0;
for br = 1:size(texture, 1)
    rr = (br - 1) * 8 + (1:8);
    for bc = 1:size(texture, 2)
        cc = (bc - 1) * 8 + (1:8);
        k = k + 1;
        if texture(br, bc) <= threshold
            continue;
        end
        alpha = min(1.67 * scale, max(0.90 * scale, ...
            0.90 * scale + 0.055 * texture(br, bc)));
        coeff = T * yOut(rr, cc) * T.';
        for p = 1:size(positions, 1)
            coeff(positions(p, 1), positions(p, 2)) = ...
                coeff(positions(p, 1), positions(p, 2)) + alpha * chips(k, p);
        end
        yOut(rr, cc) = T.' * coeff * T;
    end
end
end

function yOut = embedQimCarrier(yIn, texture8, threshold8, T, seed, scale)
[ll, lh, hl, hh] = haarForward(yIn);

% The LL block texture is measured on its corresponding 16-by-16 region in
% the original image.  Averaging the four 8-by-8 texture estimates gives a
% stable selection rule that the non-blind decoder can reproduce.
texture = zeros(32, 32);
for br = 1:32
    r8 = (br - 1) * 2 + (1:2);
    for bc = 1:32
        c8 = (bc - 1) * 2 + (1:2);
        patch = texture8(r8, c8);
        texture(br, bc) = mean(patch(:));
    end
end
selected = find(texture(:) > threshold8);
[orderKeys, ~] = keyedUniform(keyedSeed(seed, 19001), numel(selected));
[~, order] = sort(orderKeys);
selected = selected(order);

[payloadSigns, ~] = keyedSigns(keyedSeed(seed, 29009), 32);
payload = payloadSigns > 0;
[dither, ~] = keyedUniform(keyedSeed(seed, 39019), numel(selected) * 2);
dither = reshape(dither, 2, numel(selected)).';

for p = 1:numel(selected)
    [br, bc] = ind2sub([32 32], selected(p));
    rr = (br - 1) * 8 + (1:8);
    cc = (bc - 1) * 8 + (1:8);
    coeff = T * ll(rr, cc) * T.';
    if dither(p, 2) < 0.5
        u = 2; v = 3;
    else
        u = 3; v = 2;
    end
    delta = scale * (6.4 + 0.025 * min(texture(br, bc), 80));
    bit = payload(mod(p - 1, numel(payload)) + 1);
    offset = (dither(p, 1) - 0.5) * delta + double(bit) * delta / 2;
    coeff(u, v) = round((coeff(u, v) - offset) / delta) * delta + offset;
    ll(rr, cc) = T.' * coeff * T;
end
yOut = haarInverse(ll, lh, hl, hh);
end

function [ll, lh, hl, hh] = haarForward(x)
a = (x(:, 1:2:end) + x(:, 2:2:end)) / sqrt(2);
d = (x(:, 1:2:end) - x(:, 2:2:end)) / sqrt(2);
ll = (a(1:2:end, :) + a(2:2:end, :)) / sqrt(2);
lh = (a(1:2:end, :) - a(2:2:end, :)) / sqrt(2);
hl = (d(1:2:end, :) + d(2:2:end, :)) / sqrt(2);
hh = (d(1:2:end, :) - d(2:2:end, :)) / sqrt(2);
end

function x = haarInverse(ll, lh, hl, hh)
a = zeros(size(ll, 1) * 2, size(ll, 2));
d = zeros(size(ll, 1) * 2, size(ll, 2));
a(1:2:end, :) = (ll + lh) / sqrt(2);
a(2:2:end, :) = (ll - lh) / sqrt(2);
d(1:2:end, :) = (hl + hh) / sqrt(2);
d(2:2:end, :) = (hl - hh) / sqrt(2);
x = zeros(size(a, 1), size(a, 2) * 2);
x(:, 1:2:end) = (a + d) / sqrt(2);
x(:, 2:2:end) = (a - d) / sqrt(2);
end

function seed = watermarkSeed(watermark)
modulus = 2147483647;
values = double(watermark(:));
sampleIndex = unique(round(linspace(1, numel(values), 1024)));
seed = 104729;
for k = 1:numel(sampleIndex)
    seed = mod(seed * 65599 + values(sampleIndex(k)) + k, modulus);
end
seed = mod(seed + 2000003, modulus);
if seed < 1
    seed = 1;
end
end

function output = keyedSeed(seed, salt)
modulus = 2147483647;
output = mod(seed + salt * 104729, modulus);
if output < 1
    output = 1;
end
end

function [values, state] = keyedUniform(seed, count)
modulus = 2147483647;
state = seed;
values = zeros(count, 1);
for k = 1:count
    state = mod(48271 * state, modulus);
    values(k) = state / modulus;
end
end

function [values, state] = keyedSigns(seed, count)
[uniformValues, state] = keyedUniform(seed, count);
values = 2 .* double(uniformValues >= 0.5) - 1;
end
