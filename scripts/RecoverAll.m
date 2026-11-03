function [DetectedWmk Flag] = RecoverAll(MarkedImg,OriImg,OriWmk,ID,scale)
switch ID
    case 1,
        [DetectedWmk Flag] = Decoding_1(MarkedImg,OriImg,OriWmk,scale);
    case 2,
        [DetectedWmk Flag] = Decoding_2(MarkedImg,OriImg,OriWmk,scale);
    case 3,
        [DetectedWmk Flag] = Decoding_3(MarkedImg,OriImg,OriWmk,scale);
    case 4,
        [DetectedWmk Flag] = Decoding_4(MarkedImg,OriImg,OriWmk,scale);
    case 5,
        [DetectedWmk Flag] = Decoding_5(MarkedImg,OriImg,OriWmk,scale);
    case 6,
        [DetectedWmk Flag] = Decoding_6(MarkedImg,OriImg,OriWmk,scale);
    case 7,
        [DetectedWmk Flag] = Decoding_7(MarkedImg,OriImg,OriWmk,scale);
    case 8,
        [DetectedWmk Flag] = Decoding_8(MarkedImg,OriImg,OriWmk,scale);
    otherwise
        disp('Invalid GroupID or recover function missing!');
end
        