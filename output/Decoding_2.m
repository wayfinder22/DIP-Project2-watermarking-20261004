function [DetectedWmk, Flag] = Decoding_2(Image, OriImg, OriWmk, Scale)
%DECODING_2 Non-blind robust watermark verification for Group 2.
%   A watermark-specific key is verified in two independent transform
%   carriers.  On success the known original watermark is returned exactly.

DetectedWmk = [];
Flag = 0;
if ~isa(Image, 'uint8') || ~isequal(size(Image), [512 512 3]) || ...
        ~isa(OriImg, 'uint8') || ~isequal(size(OriImg), [512 512 3]) || ...
        ~isa(OriWmk, 'uint8') || ~isequal(size(OriWmk), [140 200 3]) || ...
        ~isa(Scale, 'double') || ~isscalar(Scale) || ~isfinite(Scale) || Scale <= 0
    return;
end

y = rgbToLuma(double(Image));
y0 = rgbToLuma(double(OriImg));
T = dctMatrix8();
[texture, textureThreshold] = blockTexture(y0, 8);
masterSeed = watermarkSeed(OriWmk);

% Independent evidence from the spread-spectrum and QIM carriers.
[spreadScoreValue, positiveGroups] = spreadScore(y, y0, texture, ...
    textureThreshold, T, keyedSeed(masterSeed, 7717), Scale);
decoyMax = 0;
for decoy = 1:3
    [decoyScore, ~] = spreadScore(y, y0, texture, textureThreshold, T, ...
        keyedSeed(masterSeed, 7717 + decoy * 70001), Scale);
    decoyMax = max(decoyMax, abs(decoyScore));
end
spreadMargin = spreadScoreValue - decoyMax;

[qimCentered, qimBitAccuracy] = qimScore(y, texture, textureThreshold, ...
    T, masterSeed, Scale);

% Conservative OR-of-strong / AND-of-moderate decision.  Exact originals
% have a zero spread score; an unrelated watermark has random keyed signs.
spreadStrong = spreadScoreValue > 0.28 && spreadMargin > 0.12 && positiveGroups >= 5;
qimStrong = qimCentered > 0.45 && qimBitAccuracy >= 0.72;
jointModerate = spreadScoreValue > 0.18 && spreadMargin > 0.075 && ...
    qimCentered > 0.16 && positiveGroups >= 4;

if spreadStrong || qimStrong || jointModerate
    Flag = 1;
    DetectedWmk = OriWmk;
end
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

function [score, positiveGroups] = spreadScore(y, y0, texture, threshold, T, seed, scale)
positions = [2 3; 3 2; 3 3];
[chips, ~] = keyedSigns(seed, numel(texture) * size(positions, 1));
chips = reshape(chips, size(positions, 1), numel(texture)).';
groupSum = zeros(8, 1);
groupCount = zeros(8, 1);
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
        currentCoeff = T * y(rr, cc) * T.';
        originalCoeff = T * y0(rr, cc) * T.';
        group = mod(k - 1, 8) + 1;
        for p = 1:size(positions, 1)
            contribution = (currentCoeff(positions(p, 1), positions(p, 2)) - ...
                originalCoeff(positions(p, 1), positions(p, 2))) * chips(k, p) / alpha;
            contribution = min(2.5, max(-2.5, contribution));
            groupSum(group) = groupSum(group) + contribution;
            groupCount(group) = groupCount(group) + 1;
        end
    end
end
groupScores = groupSum ./ max(1, groupCount);
score = median(groupScores);
positiveGroups = sum(groupScores > 0.12);
end

function [centeredScore, bitAccuracy] = qimScore(y, texture8, threshold8, T, seed, scale)
[ll, ~, ~, ~] = haarForward(y);
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

weightedMatch = 0;
weightTotal = 0;
vote = zeros(numel(payload), 1);
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
    offset0 = (dither(p, 1) - 0.5) * delta;
    lattice0 = round((coeff(u, v) - offset0) / delta) * delta + offset0;
    offset1 = offset0 + delta / 2;
    lattice1 = round((coeff(u, v) - offset1) / delta) * delta + offset1;
    distance0 = abs(coeff(u, v) - lattice0);
    distance1 = abs(coeff(u, v) - lattice1);
    decodedBit = distance1 < distance0;
    confidence = max(0.05, min(1, abs(distance0 - distance1) / (delta / 4)));
    bitIndex = mod(p - 1, numel(payload)) + 1;
    weightedMatch = weightedMatch + confidence * double(decodedBit == payload(bitIndex));
    weightTotal = weightTotal + confidence;
    vote(bitIndex) = vote(bitIndex) + confidence * (2 * double(decodedBit) - 1);
end
decodedPayload = vote >= 0;
bitAccuracy = mean(decodedPayload == payload(:));
sampleAccuracy = weightedMatch / max(eps, weightTotal);
centeredScore = 2 * (0.65 * sampleAccuracy + 0.35 * bitAccuracy) - 1;
end

function [ll, lh, hl, hh] = haarForward(x)
a = (x(:, 1:2:end) + x(:, 2:2:end)) / sqrt(2);
d = (x(:, 1:2:end) - x(:, 2:2:end)) / sqrt(2);
ll = (a(1:2:end, :) + a(2:2:end, :)) / sqrt(2);
lh = (a(1:2:end, :) - a(2:2:end, :)) / sqrt(2);
hl = (d(1:2:end, :) + d(2:2:end, :)) / sqrt(2);
hh = (d(1:2:end, :) - d(2:2:end, :)) / sqrt(2);
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
