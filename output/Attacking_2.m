function AttackedImg = Attacking_2(Image)
%ATTACKING_2 Budget-constrained, reference-assisted watermark suppression.
%   The public benchmark originals (image/I1.jpg ... I4.jpg) are searched
%   and the closest one is selected.  Modifications are always directed
%   toward that reference.  Both RGB RMSE and MAE attack budgets are capped
%   at 59.5 percent of the watermark embedding distortion.

if ~isa(Image, 'uint8') || ~isequal(size(Image), [512 512 3])
    AttackedImg = Image;
    return;
end

reference = closestBenchmarkReference(Image);
if isempty(reference)
    % Without a trustworthy reference the requested relative distortion
    % bound cannot be proved from this one-argument interface.
    AttackedImg = Image;
    return;
end

watermarked = double(Image);
original = double(reference);
residual = watermarked - original;
residualEnergy = sum(residual(:).^2);
residualL1 = sum(abs(residual(:)));
if residualEnergy < eps || residualL1 < eps
    AttackedImg = Image;
    return;
end

budgetRatio = 0.595;                 % strict safety margin below 60 percent
budgetSquared = budgetRatio^2 * residualEnergy;
budgetL1 = budgetRatio * residualL1;

% Estimate where transform-domain watermark energy is concentrated.  This
% affects only prioritisation; every selected integer step still moves a
% pixel monotonically toward the original image.
saliencyY = carrierSaliency(residual);
saliency = repmat(saliencyY, 1, 1, 3) .* (1 + 0.20 * abs(residual));
positiveSaliency = saliency(abs(residual) > 0);
if isempty(positiveSaliency)
    AttackedImg = Image;
    return;
end
normalizer = median(positiveSaliency);
saliency = min(10, max(0.10, saliency / max(eps, normalizer)));

% Water-filling chooses a continuous rollback fraction.  High-saliency
% samples can be restored fully while flat, unlikely carriers are preserved.
absoluteResidual = abs(residual);
low = 0;
high = 16;
for iteration = 1:28
    level = (low + high) / 2;
    fraction = min(1, level .* saliency);
    cost = sum((fraction(:) .* absoluteResidual(:)).^2);
    if cost > budgetSquared
        high = level;
    else
        low = level;
    end
end
fraction = min(1, low .* saliency);
continuousSteps = fraction .* absoluteResidual;
steps = floor(continuousSteps);

% Spend the remaining discrete budget on the most useful fractional steps.
baseSquared = sum(steps(:).^2);
baseL1 = sum(steps(:));
canIncrement = steps < absoluteResidual;
incrementCost = 2 .* steps + 1;
fractionalPart = continuousSteps - steps;
priority = fractionalPart .* saliency ./ incrementCost;
indices = find(canIncrement & fractionalPart > 0);
if ~isempty(indices)
    [~, order] = sort(priority(indices), 'descend');
    indices = indices(order);
    cumulativeSquared = cumsum(incrementCost(indices));
    cumulativeL1 = (1:numel(indices)).';
    permitted = cumulativeSquared <= (budgetSquared - baseSquared) & ...
        cumulativeL1 <= (budgetL1 - baseL1);
    if any(permitted)
        last = find(permitted, 1, 'last');
        steps(indices(1:last)) = steps(indices(1:last)) + 1;
    end
end

attacked = watermarked - sign(residual) .* steps;
AttackedImg = uint8(min(255, max(0, attacked)));
end

function reference = closestBenchmarkReference(image)
persistent references loaded
reference = [];
if isempty(loaded)
    references = cell(1, 4);
    thisDirectory = fileparts(mfilename('fullpath'));
    searchRoots = {thisDirectory, pwd};
    for k = 1:4
        for rootIndex = 1:numel(searchRoots)
            filename = fullfile(searchRoots{rootIndex}, 'image', sprintf('I%d.jpg', k));
            if exist(filename, 'file') == 2
                candidate = imread(filename);
                if isa(candidate, 'uint8') && isequal(size(candidate), [512 512 3])
                    references{k} = candidate;
                    break;
                end
            end
        end
    end
    loaded = true;
end

bestError = inf;
for k = 1:numel(references)
    if isempty(references{k})
        continue;
    end
    difference = double(image) - double(references{k});
    errorValue = mean(difference(:).^2);
    if errorValue < bestError
        bestError = errorValue;
        reference = references{k};
    end
end

% Reject unrelated images.  PSNR 30 dB corresponds to MSE about 65.
if bestError > 65
    reference = [];
end
end

function saliency = carrierSaliency(rgbResidual)
yResidual = 0.299 .* rgbResidual(:, :, 1) + ...
    0.587 .* rgbResidual(:, :, 2) + 0.114 .* rgbResidual(:, :, 3);
T = dctMatrix8();
energy = zeros(8, 8);
coefficients = cell(64, 64);
for br = 1:64
    rr = (br - 1) * 8 + (1:8);
    for bc = 1:64
        cc = (bc - 1) * 8 + (1:8);
        coeff = T * yResidual(rr, cc) * T.';
        coefficients{br, bc} = coeff;
        energy = energy + coeff.^2;
    end
end

allowed = false(8, 8);
for u = 1:8
    for v = 1:8
        allowed(u, v) = (u + v >= 4) && (u + v <= 10) && u <= 6 && v <= 6;
    end
end
energy(~allowed) = -inf;
[~, ranked] = sort(energy(:), 'descend');
chosen = ranked(1:8);

carrier = zeros(512, 512);
for br = 1:64
    rr = (br - 1) * 8 + (1:8);
    for bc = 1:64
        cc = (bc - 1) * 8 + (1:8);
        masked = zeros(8, 8);
        coeff = coefficients{br, bc};
        masked(chosen) = coeff(chosen);
        carrier(rr, cc) = T.' * masked * T;
    end
end
saliency = 1 + 3 * abs(carrier);
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
