%main   
close all
clear
%-----------------------set random para---------------------------
SamplingNum = 3;
ImgInd = ceil(rand(1,SamplingNum)*4+0.5);  % 1-22
WmkInd = ceil(rand(1,SamplingNum)*4+0.5);  % 1-20

GroupNum = 1;  
DefendGroupInd = 1; % Set this number as your group ID
AttackGroupInd = 1; % Set this number as your group ID

scrsz = get(0,'ScreenSize');
%-------------------------loop begin---------------------------
for i = 1:SamplingNum
    Imgstr = strcat('image\I',num2str(ImgInd(i)),'.jpg');
    Wmkstr = strcat('watermark\m',num2str(WmkInd(i)),'.jpg');
    Img = imread(Imgstr);
    Wmk = imread(Wmkstr);
    CheckTresh = 0;
    ULposR = floor((size(Img,1)-size(Wmk,1))/2)+1;
    ULposC = floor((size(Img,2)-size(Wmk,2))/2)+1;
    
    for j = 1:GroupNum
        [WatermarkedImg nScale]= EncodingAll(Img,Wmk,DefendGroupInd(j));
        AttackedImg = AttackAll(WatermarkedImg,AttackGroupInd(j));
        
        if(rand(1)>CheckTresh) % Random Check
            [DetectedWmk Flag] = RecoverAll(Img,Img,Wmk,DefendGroupInd(j),nScale);
            figure(1)
            imshow(DetectedWmk)
            tlstr = strcat('Extracted watermark-Group',num2str(DefendGroupInd(j)));
            title(tlstr)
            if(Flag == 1)
                disp('Warning!')
                disp(tlstr)
            end            
        end
        
        [DetectedWmk Flag] = RecoverAll(AttackedImg,Img,Wmk,DefendGroupInd(j),nScale);
        PadWmk = uint8(zeros(size(Img)));
        if(Flag == 1)
            PadWmk(ULposR:ULposR+size(Wmk,1)-1,ULposC:ULposC+size(Wmk,2)-1,:) = DetectedWmk;
        end
        
        ImgSave = [Img,WatermarkedImg,AttackedImg,PadWmk];
        Filestr = sprintf('%d_%d.bmp',[i j]);
        imwrite(ImgSave,Filestr,'BMP');
    end
end
%-------------------------loop end-----------------------------
