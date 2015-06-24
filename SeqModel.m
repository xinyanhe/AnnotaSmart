classdef SeqModel < handle
    properties
        m_seqFile
        m_fName
        m_hImg
        m_curFrm
        m_numFrm
        m_FrameObjArray = []
        m_objEndFrmMap
        m_objStartFrmMap
        m_hFig
        m_hAx
        m_state = 0
        
        m_frmNumChangeCallBack
    end
    properties(Constant)
        STATUS_STOP = 0;
        STATUS_PlAY = 1;
    end
    
    methods(Static)
        function obj = getSeqFileInstance(fName)         %Static API
            persistent localObj                          %Persistent Local obj
             if ~isempty(localObj) && isvalid(localObj)
                localObj.m_seqFile.close();            %close seq file
             end
             localObj = SeqModel(fName);
             obj = localObj;
        end
        
    end
    
    methods(Access = private)
        function obj = SeqModel(fName)
                if nargin < 1
                    obj.m_seqFile = [];
                    obj.m_fName = [];
                else
                    obj.openSeqFile(fName);
                end
        end
    end

    methods
        function setCurFigAndAxes(obj, hFig, hAx)
            obj.m_hFig = hFig;
            obj.m_hAx = hAx;
        end
        
        function frmArray = getFrmArray(obj)
            frmArray = obj.m_FrameObjArray;
        end
        
        function bbId = addBBToAFrm(obj, selectedFcn, frmNum, oldBBId, pos, isdraw)
            if nargin < 4
                curFrmObj = obj.m_FrameObjArray(obj.m_curFrm);
                bbObj = BBModel(obj.m_hFig, obj.m_hAx, selectedFcn);%create a new id BB
                curFrmObj.addObj(bbObj);
                obj.m_objStartFrmMap(num2str(bbObj.getObjId())) = obj.m_curFrm;
                obj.m_objEndFrmMap(num2str(bbObj.getObjId())) = obj.m_curFrm;
            else
                curFrmObj = obj.m_FrameObjArray(frmNum);
                bbObj = BBModel(obj.m_hFig, obj.m_hAx, selectedFcn,oldBBId, pos, isdraw);%create an old id BB
                curFrmObj.addObj(bbObj);
                keyStr = num2str(bbObj.getObjId());
                if isKey(obj.m_objEndFrmMap, keyStr)
                    endFrmNum = obj.m_objEndFrmMap(keyStr);
                    if endFrmNum < frmNum
                         obj.m_objEndFrmMap(keyStr) = frmNum;
                    end
                else
                    obj.m_objStartFrmMap(keyStr) = frmNum;
                    obj.m_objEndFrmMap(keyStr) = frmNum;
                end  
            end
            bbId = bbObj.getObjId();
        end
        
        function LoadAnnotaFile(obj, selectedFcn, fullFileName)
            obj.clearAllAnnota();
            file = fopen(fullFileName, 'r');
            line = fgetl(file);
            while line ~= -1;
                textCell = textscan(line, '%d %d %d %d %d %d');
                frmNum = textCell{1};
                bbId = textCell{2};
                pos = [textCell{3:6}];
                isdraw = 0;
                if frmNum == obj.m_curFrm
                    isdraw = 1;
                end
                obj.addBBToAFrm(selectedFcn, frmNum, bbId, pos, isdraw);
                line = fgetl(file);
            end 
            fclose(file);
        end
        
        function saveAnnotaFile(obj, fileFullName)
            file = fopen(fileFullName, 'w');
            numFrm = obj.m_numFrm;
     
            for i = 1:numFrm
                frmObj = obj.m_FrameObjArray(i);
                objSet = values(frmObj.m_bbMap);
                len = length(objSet);
                for j = 1:len
                   bbObj = objSet{j};
                   id = bbObj.getObjId();
                   pos = bbObj.getPos();
                   fprintf(file, '%d %d %f %f %f %f\n',...
                       i, id, pos(1), pos(2), pos(3), pos(4)); 
                end
            end
            fclose(file);
        end
        
        function clearAllAnnota(obj)
            numFrm = length(obj.m_FrameObjArray);
            for i = 1:numFrm
                frmObj = obj.m_FrameObjArray(i);
                frmObj.removeAllbb();
            end
            
            keySet = keys(obj.m_objEndFrmMap);
            if ~isempty(keySet)
                remove(obj.m_objEndFrmMap, keySet);
            end
            
            keySet = keys(obj.m_objStartFrmMap);
            if ~isempty(keySet)
                remove(obj.m_objEndFrmMap, keySet);
            end
        end
        
        function pos = nextPosEstimate(obj, bbId)
            pos = [];
            startFrmNum = obj.m_objStartFrmMap(num2str(bbId));
            numDif = obj.m_curFrm - startFrmNum;
            if numDif == 2
                 frmObj1 = obj.m_FrameObjArray(obj.m_curFrm - 2);
                 frmObj2 = obj.m_FrameObjArray(obj.m_curFrm - 1);
                 bbObj =  frmObj1.getObj(bbId);
                 if isempty(bbObj)
                     return;
                 end
                 pos1 = bbObj.getPos();
                 bbObj =  frmObj2.getObj(bbId);
                 if isempty(bbObj)
                     return;
                 end
                 pos2 = bbObj.getPos();
                 pos = pos2 + (pos2 - pos1);
            elseif numDif > 2
                frmObj0 = obj.m_FrameObjArray(obj.m_curFrm - 3);
                frmObj2 = obj.m_FrameObjArray(obj.m_curFrm - 1);
               
                bbObj = frmObj0.getObj(bbId);
                if isempty(bbObj)
                    return;
                end
                pos0 = bbObj.getPos();  

                bbObj =  frmObj2.getObj(bbId);
                if isempty(bbObj)
                    return;
                end
                pos2 = bbObj.getPos();
                
                pos = pos2 + (pos2 - pos0)/2;
                c = pos(1:2) + pos(3:4)/2;
                h = obj.perspecProjectionEst(pos0(4)/2, pos2(4)/2);
                h = 2*h;
                w = obj.perspecProjectionEst(pos0(3)/2, pos2(3)/2);
                w = 2*w;
                pos(3) = w;
                pos(4) = h;
                pos(1) = c(1) - w/2;
                pos(2) = c(2) - h/2;
            elseif numDif == 1
                frmObj = obj.m_FrameObjArray(startFrmNum);
                bbObj = frmObj.getObj(bbId);
                pos = bbObj.getPos();
            end
        end
        
        function x = perspecProjectionEst(obj, x0, x2)         
            x = 2*x0*x2;
            x = x/(3*x0 - x2);
        end
        
        
        function pasteAnnotation(obj,selectedFcn,bbId)
            pos = obj.nextPosEstimate(bbId);
            if isempty(pos)
                return;
            end
            curFrmObj = obj.getCurFrmObj();
            isdraw = 1;
            curFrmObj.removeObj(bbId);
            obj.addBBToAFrm(selectedFcn, obj.m_curFrm, bbId, pos, isdraw)
        end
        
        function numBB = bbObjNumInCurFrm(obj)
            frmObj = obj.m_FrameObjArray(obj.m_curFrm);
            numBB = frmObj.m_bbMap.Count;
        end
        function frmObj = getCurFrmObj(obj)
            frmObj = obj.m_FrameObjArray(obj.m_curFrm);
        end
        
        function bbObj = getBBObj(obj, frmNum, bbId)
            curFrmObj = obj.m_FrameObjArray(frmNum);
            bbObj = curFrmObj.getObj(bbId);
        end

        function openSeqFile(obj, fName)
            obj.m_seqFile = seqIo( fName,'r');
            info = obj.m_seqFile.getinfo();
            for i = 1:info.numFrames
                obj.m_FrameObjArray = [obj.m_FrameObjArray FrameModel()];
            end
            obj.m_state = obj.STATUS_STOP;
            obj.m_curFrm = 0;
            obj.m_objEndFrmMap = containers.Map();
            obj.m_objStartFrmMap = containers.Map();
            obj.m_fName = fName;
            obj.m_numFrm = obj.getNumFrames();
        end
        
        function numFrames = getNumFrames(obj)
               info = obj.m_seqFile.getinfo();
               numFrames = info.numFrames;
        end
        
        function [width, height] = getFrameSize(obj)
             info = obj.m_seqFile.getinfo();
             height = info.height;
             width = info.width;
        end
        
        function videoPlay(obj, viewObj)
            obj.setStatus(obj.STATUS_PlAY);
            numFrames = obj.m_numFrm;
            startFrmNum = obj.m_curFrm + 1;
            for i = startFrmNum:numFrames 
                if obj.getStatus() == obj.STATUS_STOP
                     break;
                end
                obj.seqPlay(i-1, i);
                obj.m_curFrm = i;       
            end
                 
        end
        
        function videoPause(obj)
             obj.setStatus(obj.STATUS_STOP);
        end
        
        function displayNextFrame(obj)
            numFrames = obj.m_numFrm;
            obj.m_curFrm = obj.m_curFrm + 1;

            if obj.m_curFrm <= numFrames
                obj.seqPlay(obj.m_curFrm - 1,obj.m_curFrm);
            else
                obj.m_curFrm = 0;
            end
        end
        
        function displayLastFrame(obj)
            obj.m_curFrm = obj.m_curFrm - 1;

            if obj.m_curFrm >= 1
                obj.seqPlay(obj.m_curFrm + 1, obj.m_curFrm);
            else
                obj.m_curFrm = 0;
            end
        end

        function seqPlay(obj, lastFrmNum, curFrmNum)
            if isempty(obj.m_seqFile)
                return;
            end            
            obj.m_curFrm = curFrmNum;
            img = obj.getImg(curFrmNum);
            obj.setImgHandleForDisplay(img);
            obj.updateAnnotations(lastFrmNum, curFrmNum);
            drawnow();
            if ~isempty(obj.m_frmNumChangeCallBack)
                obj.m_frmNumChangeCallBack();
            end
            
        end
        
        function clearDisplayObj(obj, frmNum)
            frmObj =  obj.m_FrameObjArray(frmNum);
            objSet = values(frmObj.m_bbMap);
            len = length(objSet);
            for i = 1:len
                objSet{i}.deleteRect();
            end
        end
        
        function displayObj(obj, frmNum)
            frmObj =  obj.m_FrameObjArray(frmNum);
            objSet = values(frmObj.m_bbMap);
            len = length(objSet);
            for i = 1:len
                objSet{i}.drawRect();
            end
        end
        
        function updateAnnotations(obj, lastFrmNum, curFrmNum)
          if  lastFrmNum > 0 && lastFrmNum <= obj.m_numFrm
              obj.clearDisplayObj(lastFrmNum);  
          end
          obj.displayObj(curFrmNum)
        end
        
        function setImgHandleForDisplay(obj, img)
            if(isempty(obj.m_hImg)) 
                %IMAGE(C) displays matrix C as an image.IMAGE returns a handle to an IMAGE object.
                obj.m_hImg = image(img);
                axis off;
            else
                set(obj.m_hImg,'CData',img);
            end
        end
        
        function img = getImg(obj, index)
            obj.m_seqFile.seek(index);
            img = obj.m_seqFile.getframe();
            if(ismatrix(img))
                img = img(:, :, [1 1 1]);
            end
        end
        function state = getStatus(obj)
            state = obj.m_state;
        end
        
        function setStatus(obj, status)
            obj.m_state = status;
        end
        
        function deleteBBObj(obj, bbId)
            %delete obj from curframe to the endFrm
            endFrmNum = obj.m_objEndFrmMap(num2str(bbId));
            frmNum = obj.m_curFrm;
            if frmNum > obj.m_objStartFrmMap(num2str(bbId))
                obj.m_objEndFrmMap(num2str(bbId)) = frmNum - 1;
            else
                 remove(obj.m_objEndFrmMap, num2str(bbId));
                 remove(obj.m_objStartFrmMap, num2str(bbId));
            end
            for i = frmNum:endFrmNum
                frmObj = obj.m_FrameObjArray(i);
                frmObj.removeObj(bbId);
            end
        end
        
        function setFrameNumChangeCallback(obj, funcH)
            obj.m_frmNumChangeCallBack = funcH;
        end
        
        function delete(obj)
            obj.m_seqFile.close();                                %release the memory
        end
    end
    
end

