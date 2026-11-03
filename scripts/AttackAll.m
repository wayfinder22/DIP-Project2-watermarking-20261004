function AttackedImg = AttackAll(MarkedImg,ID)
switch ID
    case 1,
        AttackedImg = Attacking_1(MarkedImg);
    case 2,
        AttackedImg = Attacking_2(MarkedImg);
    case 3,
        AttackedImg = Attacking_3(MarkedImg);
    case 4,
        AttackedImg = Attacking_4(MarkedImg);
    case 5,
        AttackedImg = Attacking_5(MarkedImg);
    case 6,
        AttackedImg = Attacking_6(MarkedImg);
    case 7,
        AttackedImg = Attacking_7(MarkedImg);
    case 8,
        AttackedImg = Attacking_8(MarkedImg);
    otherwise
        disp('Invalid GroupID or attack function missing!');
end
        