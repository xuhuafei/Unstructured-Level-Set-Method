function G = calcGradient(p, phi, ovData, A, S, edgeWeights, isUseExtrapolation)
isUseExtrapolation=false;

NPoints=size(phi,1);
% 2D
G=zeros(NPoints, 2);
eps_=1e-3;

if size(S,2) > 1
    isUseSxyAsMainAxis=true;
    Sx=S(:,1);
    Sy=S(:,2);
else
    isUseSxyAsMainAxis=false;
    Sx=S;
    Sy=S;
end

A1=A(:,1);
A2=A(:,2);
A3=A(:,3);
A4=A(:,4);

ovData1=ovData(:,1);
ovData2=ovData(:,2);
ovData3=ovData(:,3);
ovData4=ovData(:,4);
ovData5=ovData(:,5);

edgeWeights1=edgeWeights(:,1);
edgeWeights2=edgeWeights(:,2);
edgeWeights3=edgeWeights(:,3);
edgeWeights4=edgeWeights(:,4);

global nearZeroThreshold;
global divergenceThreshold;

for idxP=1:NPoints
    
    crtPhi=phi(idxP);
    crtCoordinate=p(idxP,:);
    ovEndPhi=phi(ovData5{idxP}{2});
    isOnZeroContour=(crtPhi > eps_ && sum(ovEndPhi < -eps_) > 0) ...
        || (crtPhi < -eps_ && sum(ovEndPhi > eps_));
    %isOnZeroContour=false;
    isBesideZero=abs(crtPhi) < nearZeroThreshold;
    
    myOVEdges=ovData5{idxP}{1};
    myOVEdgesMid=ovData5{idxP}{3};
    myOVEdgesMidIndices=ovData5{idxP}{4};

    
    if isOnZeroContour && (~isUseSxyAsMainAxis)
        
        % zeroContourEdges: [x1, y1, x2, y2];
        zeroContourEdges1=zeros(size(myOVEdgesMidIndices));
        zeroContourEdges2=zeros(size(myOVEdgesMidIndices));
        nZeroContourEdges=0;
        
        for i = 1:size(myOVEdgesMidIndices,1)
            triangleOtherVertices=myOVEdgesMidIndices(i,:);
            phiArray=[crtPhi;phi(triangleOtherVertices)];
            
            % see if this triangle is on zero contour
            if sum(phiArray>eps_)>0 && sum(phiArray<-eps_)>0
                
                % see if we need to filter the triangle
                if isUseSxyAsMainAxis
                    divergence=dot([Sx(idxP) Sy(idxP)], myOVEdgesMid(i, 3:4));
                    
                    % check for safe
                    if abs(divergence) > 1
                        error('divergence cannot > 1')
                    end
                    
                    if divergence < divergenceThreshold + 0.1
                        continue;
                    end
                end
                
                nZeroContourEdges=nZeroContourEdges+1;
            
                % find the edge and add to zeroContourEdges
                [lineSeg1, lineSeg2] = findContourInTriangle(p([idxP, triangleOtherVertices],:), phiArray);
                zeroContourEdges1(nZeroContourEdges,:)=lineSeg1;
                zeroContourEdges2(nZeroContourEdges,:)=lineSeg2;
            end
        end
        
        zeroContourEdges1(nZeroContourEdges+1:end,:)=[];
        zeroContourEdges2(nZeroContourEdges+1:end,:)=[];
        
        % find the nearest point
        nearestPoint=[];
        nearestDistance=Inf;
        for i=1:nZeroContourEdges
            [xy,dis,~]=distance2curve([zeroContourEdges1(i,:);zeroContourEdges2(i,:)],crtCoordinate);
            if dis < nearestDistance
                nearestPoint=xy;
                nearestDistance=dis;
            end
        end
        
        % calc real gradient
        gradientDirection=normr(nearestPoint-crtCoordinate);
        G(idxP,:)=gradientDirection*(-crtPhi)/nearestDistance;

    elseif isBesideZero
        
        changingAmount=ovEndPhi-crtPhi;
        changingRate=(changingAmount)./(myOVEdges(:,5));

        
        % find the vertex aiming at zero or aiming to upwind of S
        if isUseSxyAsMainAxis
            aimingDirection=-normr([Sx(idxP), Sy(idxP)]);
        else
            if crtPhi > 0
                [~,im]=min(changingRate);
            else
                [~,im]=max(changingRate);
            end
            aimingDirection=myOVEdges(im,3:4);
        end
        
        [GAiming1,OK1] = estimateGradientOnOneDirection(aimingDirection, myOVEdges, changingAmount, changingRate,...
            myOVEdgesMid, myOVEdgesMidIndices, crtPhi, phi, isUseExtrapolation);
        
        if OK1
            G(idxP,:)=GAiming1;
        else
            error('aimingDirection unavailable');
        end
% 
%         % if this is reinitial (i.e. isUseSxyAsMainAxis == false), use
%         % Godunov's scheme
%         if ~isUseSxyAsMainAxis
%             % GAiming1 & OK 1 are estimated on aimingDirection
%             % GAiming2 & OK 2 are estimated on -aimingDirection
%             [GAiming2,OK2] = estimateGradientOnOneDirection(-aimingDirection, myOVEdges, changingAmount, changingRate,...
%                 myOVEdgesMid, myOVEdgesMidIndices, crtPhi, phi, isUseExtrapolation);
%             if OK1 && OK2
%                 if aimingDirection(1) > 0
%                     GXP=GAiming1(1);
%                     GXN=GAiming2(1);
%                 else
%                     GXP=GAiming2(1);
%                     GXN=GAiming1(1);
%                 end
%                 
%                 if aimingDirection(2) > 0
%                     GYP=GAiming1(2);
%                     GYN=GAiming2(2);
%                 else
%                     GYP=GAiming2(2);
%                     GYN=GAiming1(2);
%                 end
%                 
%                 G(idxP,:)=[Godunov(GXN,GXP,Sx(idxP)) Godunov(GYN,GYP,Sy(idxP))];
%             elseif OK1
%                 G(idxP,:)=GAiming1;
%             elseif OK2
%                 G(idxP,:)=GAiming2;
%             else
%                 error('This cannot happen!');
%             end
%         else
%             % if this is used for evolving, just try another side of the
%             % main axis
%             if ~OK1
%                 [GAiming1,OK1] = estimateGradientOnOneDirection(-aimingDirection, myOVEdges, changingAmount, changingRate,...
%                     myOVEdgesMid, myOVEdgesMidIndices, crtPhi, phi, isUseExtrapolation);
%                 if ~OK1
%                     error('Estimations of both sides are unavailable!');
%                 end
%             end
%             G(idxP,:)=GAiming1;
%         end
    else
        % if this vertex is far from phi==0 isosurface
        GXPOK=A1(idxP).OK;
        if GXPOK
            GXP=calcGradient1Axis1Vertex(phi,crtPhi,...
                ovData1{idxP}{1,2},ovData1{idxP}{1,4},A1(idxP).A,edgeWeights1{idxP});
        end
        
        GXNOK=A2(idxP).OK;
        if GXNOK
            GXN=calcGradient1Axis1Vertex(phi,crtPhi,...
                ovData2{idxP}{1,2},ovData2{idxP}{1,4},A2(idxP).A,edgeWeights2{idxP});
        end
        
        GYPOK=A3(idxP).OK;
        if GYPOK
            GYP=calcGradient1Axis1Vertex(phi,crtPhi,...
                ovData3{idxP}{1,2},ovData3{idxP}{1,4},A3(idxP).A,edgeWeights3{idxP});
        end
        
        GYNOK=A4(idxP).OK;
        if GYNOK
            GYN=calcGradient1Axis1Vertex(phi,crtPhi,...
                ovData4{idxP}{1,2},ovData4{idxP}{1,4},A4(idxP).A,edgeWeights4{idxP});
        end
        
        GXOK=GXPOK && GXNOK;
        GXPMissing=(~GXPOK) && GXNOK;
        GXNMissing=GXPOK && (~GXNOK);
        if (~GXPOK) && (~GXNOK)
            error('Unavailabel!')
        end
        
        GYOK=GYPOK && GYNOK;
        GYPMissing=(~GYPOK) && GYNOK;
        GYNMissing=GYPOK && (~GYNOK);
        if (~GYPOK) && (~GYNOK)
            error('Unavailabel!')
        end
        
        if GXOK
            GX=Godunov(GXN(1),GXP(1),Sx(idxP));
        else
            if GXNMissing
                GX=GXP(1);
            end
            if GXPMissing
                GX=GXN(1);
            end
        end
        
        if GYOK
            GY=Godunov(GYN(2),GYP(2),Sy(idxP));
        else
            if GYNMissing
                GY=GYP(2);
            end
            if GYPMissing
                GY=GYN(2);
            end
        end
        
%         if GXPMissing || GXNMissing || GYPMissing || GYNMissing
%             if (GXNMissing) && (abs(GY) < eps) && GX > 0
%                 GX=max(0,2-GX);
%             elseif (GYNMissing) && (abs(GX) < eps) && GY > 0
%                 GY=max(0,2-GY);
%             elseif (GXPMissing) && (abs(GY) < eps) && GX < 0
%                 GX=min(0,-2-GX);
%             elseif (GYPMissing) && (abs(GX) < eps) && GY < 0
%                 GY=min(0,-2-GY);
%             end
%         end
        
        G(idxP,:)=[GX,GY];
    end
end

end

function [G,OK]=calcGradientViaExplicitGeometry(myOVEdgesMidIndices, crtPhi, phi, isUseSxyAsMainAxis)

% zeroContourEdges: [x1, y1, x2, y2];
zeroContourEdges1=zeros(size(myOVEdgesMidIndices));
zeroContourEdges2=zeros(size(myOVEdgesMidIndices));
nZeroContourEdges=0;

for i = 1:size(myOVEdgesMidIndices,1)
    triangleOtherVertices=myOVEdgesMidIndices(i,:);
    phiArray=[crtPhi;phi(triangleOtherVertices)];
    signArray=sign(phiArray);
    
    % see if this triangle is on zero contour
    if ~all(signArray == signArray(1))
        
        % see if we need to filter the triangle
        if isUseSxyAsMainAxis
            divergence=dot([Sx(idxP) Sy(idxP)], myOVEdgesMid(i, 3:4));
            
            % check for safe
            if abs(divergence) > 1
                error('divergence cannot > 1')
            end
            
            if divergence < divergenceThreshold + 0.1
                continue;
            end
        end
        
        nZeroContourEdges=nZeroContourEdges+1;
        
        % find the edge and add to zeroContourEdges
        [lineSeg1, lineSeg2] = findContourInTriangle(p([idxP, triangleOtherVertices],:), phiArray);
        zeroContourEdges1(nZeroContourEdges,:)=lineSeg1;
        zeroContourEdges2(nZeroContourEdges,:)=lineSeg2;
    end
end

zeroContourEdges1(nZeroContourEdges+1:end,:)=[];
zeroContourEdges2(nZeroContourEdges+1:end,:)=[];

% find the nearest point
nearestPoint=[];
nearestDistance=Inf;
for i=1:nZeroContourEdges
    [xy,dis,~]=distance2curve([zeroContourEdges1(i,:);zeroContourEdges2(i,:)],crtCoordinate);
    if dis < nearestDistance
        nearestPoint=xy;
        nearestDistance=dis;
    end
end

% calc gradient
gradientDirection=normr(nearestPoint-crtCoordinate);
G=gradientDirection*(-crtPhi)/nearestDistance;
OK=true;
end

function [GM,OK] = calcGradientViaExtrapolation(divergence,changingRates)
R=[divergence.^3,divergence.^2,divergence]\(divergence.*changingRates);

GM=sum(R);

OK = (abs(2 * R(1) + R(2)) < 2) || (abs(GM) > 0.3 && abs(GM) < 1.5);
end

function [G] = calcGradient1Axis1Vertex(phi,crtPhi,OVTags,OVMidTags,dA,weight)
changingAmount=(phi(OVTags)-crtPhi);

phiMid=(phi(OVMidTags(:,1))+phi(OVMidTags(:,2)))./2;
changingAmountMid=(phiMid-crtPhi);

b=[changingAmount;changingAmountMid] .* weight;
G=dA\b;
end

function [G,OK] = estimateGradientOnOneDirection(aimingDirection, myOVEdges, changingAmount, changingRate,...
    myOVEdgesMid, myOVEdgesMidIndices, crtPhi, phi, isUseExtrapolation)

global scale;
gridScale=scale;
global divergenceThreshold;
crtDivergenceThreshold=divergenceThreshold;
global extrapolationThreshold;

% find the region where gradient vector may exist
% construct A
realEdgeDivergence=dot(myOVEdges(:,3:4),repmat(aimingDirection,size(myOVEdges,1),1),2);
midEdgeDivergence=dot(myOVEdgesMid(:,3:4),repmat(aimingDirection,size(myOVEdgesMid,1),1),2);
isRealEdgeDivergenceAccepted=realEdgeDivergence>crtDivergenceThreshold;
isMidEdgeDivergenceAccepted=midEdgeDivergence>crtDivergenceThreshold;

OK = (sum(isRealEdgeDivergenceAccepted) + sum(isMidEdgeDivergenceAccepted)) >= 2;

if ~OK
    G=[0,0];
    return;
end

weights=[realEdgeDivergence(isRealEdgeDivergenceAccepted);...
    midEdgeDivergence(isMidEdgeDivergenceAccepted)];
A=[myOVEdges(isRealEdgeDivergenceAccepted,1:2);myOVEdgesMid(isMidEdgeDivergenceAccepted,1:2)]...
    .*weights;
b=[changingAmount(isRealEdgeDivergenceAccepted);...
    (phi(myOVEdgesMidIndices(isMidEdgeDivergenceAccepted,1)) +...
    phi(myOVEdgesMidIndices(isMidEdgeDivergenceAccepted,2)))./2 - crtPhi]...
    .*weights;
gradientEstimatedVia1stStep=A\b;

% regression error
maxRegressionError=max(abs(A*gradientEstimatedVia1stStep-b));

if (maxRegressionError > extrapolationThreshold*gridScale) && isUseExtrapolation
    gradientEstimatedVia1stStepNorm=normc(gradientEstimatedVia1stStep);
    realEdgeDivergence=dot(myOVEdges(:,3:4),repmat(gradientEstimatedVia1stStep',size(myOVEdges,1),1),2);
    
    % edges on two sides of the "main axis"
    isEdgeOnAimingSide=realEdgeDivergence>crtDivergenceThreshold;
    
    extrapolationOK=sum(isEdgeOnAimingSide)>=3;
    
    if extrapolationOK
        [maxSideGM,extrapolationOK] = calcGradientViaExtrapolation(...
            realEdgeDivergence(isEdgeOnAimingSide),...
            changingRate(isEdgeOnAimingSide));
        maxSideG=maxSideGM*gradientEstimatedVia1stStepNorm;
    end
    
    if extrapolationOK
        G=maxSideG';
    else
        G=gradientEstimatedVia1stStep';
    end
    
else
    G=gradientEstimatedVia1stStep';
end
end

function R = Godunov(negativeDiff,positiveDiff,S)
if S>0
    if (negativeDiff <= 0 && positiveDiff <= 0)
        R=positiveDiff;
        return;
    end
    if (negativeDiff >= 0 && positiveDiff >= 0)
        R=negativeDiff;
        return;
    end
    if (negativeDiff > 0 && positiveDiff < 0)
        if (abs(negativeDiff) > abs(positiveDiff))
            R=negativeDiff;
            return;
        else
            R=positiveDiff;
            return;
        end
    else
        R=0;
        return;
    end
else
    if (negativeDiff <= 0 && positiveDiff <= 0)
        R=negativeDiff;
        return;
    end
    if (negativeDiff >= 0 && positiveDiff >= 0)
        R=positiveDiff;
        return;
    end
    if (negativeDiff < 0 && positiveDiff > 0)
        if (abs(negativeDiff) > abs(positiveDiff))
            R=negativeDiff;
            return;
        else
            R=positiveDiff;
            return;
        end
    else
        R=0;
        return;
    end
end
end
