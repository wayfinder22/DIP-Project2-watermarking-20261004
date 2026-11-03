function [MarkImg scale] = EncodingAll(OriImg,Print,ID)
switch ID
    case 1,
        [MarkImg scale] = Encoding_1(OriImg,Print);
    case 2,
        [MarkImg scale] = Encoding_2(OriImg,Print);
    case 3,
        [MarkImg scale] = Encoding_3(OriImg,Print);
    case 4,
        [MarkImg scale] = Encoding_4(OriImg,Print);
    case 5,
        [MarkImg scale] = Encoding_5(OriImg,Print);
    case 6,
        [MarkImg scale] = Encoding_6(OriImg,Print);
    case 7,
        [MarkImg scale] = Encoding_7(OriImg,Print);
    case 8,
        [MarkImg scale] = Encoding_8(OriImg,Print);
    otherwise
        disp('Invalid GroupID or function missing!');
end
        