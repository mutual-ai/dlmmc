function [objFunVal, grad] = mmc_grad_func(x, train_X,network, nClusters,...
                                       Y_t, Z_minus_t, Z_plus_t, ...
                                       I_NonMC_vec,...                     % i\in U  
                                       I_C_vec, J_C_vec,...                %(i,j)\in C 
                                       I_M_vec, J_M_vec,...                %(i,j)\in M 
                                       initW_vec, lambda, innerTol, preIteration, t, cOne)

                                   
flag =0;                                   
                                   
                                   
objFunVal = 0;                                   


% reshape x back to the data 
[dim] = size(network{1}.W,2);
indx =1;
%W = reshape(x(indx:indx+numel(initW_vec)-1), [dim nClusters]); indx = indx + numel(initW_vec);
W = x(indx:indx+numel(initW_vec)-1); indx = indx + numel(initW_vec);
network{1}.W = reshape(x(indx:indx+ numel(network{1}.W)-1), size(network{1}.W)); indx = indx + numel(network{1}.W);

network{1}.bias_upW = reshape(x(indx:indx+ numel(network{1}.bias_upW)-1), 1, dim); 

% embeddings via projection
pX = projection(network, train_X, length(network)-1);
pX = pX';

[numdims, nPoints]= size(pX);
pX = pX - repmat(mean(pX,2), 1, nPoints);

% get the initial value
vWh  = [network{1}.W; network{1}.bias_upW];

[dim, nPoints] = size(pX);
dX = zeros(nPoints,dim);

sizeOfU = length(I_NonMC_vec);

nComb = 0;
for p = 1:nClusters
    for q = 1:nClusters
        if q~=p
            nComb = nComb + 1;
            CombIndex{nComb} = [p q];
        end            
    end
end



%
if (ismember(t,0:preIteration))    
    radius = sqrt( 1 ./ lambda );
else
    radius = sqrt( ( 1 + cOne ) ./ lambda );    
end


%initW_vec = randn(dim*nClusters,1);


% W_vec = min(1, radius./norm(initW_vec)) * initW_vec(:);
W_vec = min(1, radius./norm(W)) * W(:);

innerConvergence = 0;
s = 1;
% while (innerConvergence == 0)
    
    if flag        
       % embeddings via projection
        pX = projection(network, train_X);
        pX = pX';

        [dim, nPoints]= size(pX);
        pX = pX - repmat(mean(pX,2), 1, nPoints);

        % get the initial value
        vWh  = [network{1}.W; network{1}.bias_upW];

        [dim, nPoints] = size(pX);
        dX = zeros(nPoints,dim); 
    end
    
    W = reshape(W_vec,[dim nClusters]);
   
    
    error_NonMC = 0;
    % find z_i for i in UZ^{violation}        
    if (~ismember(t,0:preIteration)) %-------------------------------------------            
        
        subGradPvio = zeros(dim * nClusters, 1);
        scores =  ( W') * pX(:,I_NonMC_vec);
        [val, idx] = sort(scores,1, 'descend');
        for i = 1 : sizeOfU   
            
            y_i = idx(1);
            z_i = idx(2);
            margin = scores(y_i, i) - scores(z_i,i); 
             
            if  margin < 1
                subGradPvio = subGradPvio + ( mapByY( pX(:,I_NonMC_vec(i)) , z_i , nClusters ) - mapByY( pX(:,I_NonMC_vec(i)) , y_i , nClusters )  );
                error_NonMC = error_NonMC + 1 - margin;

                dX(I_NonMC_vec(i),:) = dX(I_NonMC_vec(i),:) - 1/(sizeOfU*nClusters + eps).*(W(:,y_i) - W(:,z_i))';

            end
            
%              for z_i = 1: nClusters
%                 margin = ( W(:,Y_t(i))' - W(:,z_i)' ) * pX(:,I_NonMC_vec(i));
%                  if  margin < 1
%                      subGradPvio = subGradPvio + ( mapByY( pX(:,I_NonMC_vec(i)) , z_i , nClusters ) - mapByY(pX(:,I_NonMC_vec(i)) , Y_t(i) , nClusters) );
%                      error_NonMC = error_NonMC + 1 - margin;
%                      
%                  
%                      
%                      dX(I_NonMC_vec(i),:) = dX(I_NonMC_vec(i),:) - 1/(sizeOfU*nClusters + eps).*W(:,Y_t(i))';
%                      
%                  end
%              end            
        end   
    end %-------------------------------------------
    
    % find (Z_i^-(s), Z_j^-(s)) for (i,j)\in M^{violation}
    combScore = [];% will be [ k(k-1) x length(I_M_vec)]
    for i = 1:nComb
        combScore = [combScore; W(:,CombIndex{i}(1))' * pX(:,I_M_vec) + W(:,CombIndex{i}(2))' * pX(:,J_M_vec)];
    end
    [C, CombIndex_minus_s] = max(combScore);
    error_M = 0;
    subGradMvio = zeros(dim * nClusters, 1);
    for i = 1 : length(I_M_vec)
        Z_minus_s{i} = CombIndex{CombIndex_minus_s(i)};%Z_minus_s{i}=[p, q]
        similarityMargin = W(:,Z_plus_t(i))' * ( pX(:,I_M_vec(i)) + pX(:,J_M_vec(i)) ) -...
                         ( W(:,Z_minus_s{i}(1))' * pX(:,I_M_vec(i)) + W(:,Z_minus_s{i}(2))' * pX(:,J_M_vec(i)) );                     
        if similarityMargin < 1
            subGradMvio = subGradMvio + ( mapByY( pX(:,I_M_vec(i)) , Z_minus_s{i}(1) , nClusters ) + mapByY( pX(:,J_M_vec(i)) , Z_minus_s{i}(2) , nClusters ) ) ...
                                      - ( mapByY( pX(:,I_M_vec(i)) , Z_plus_t(i)     , nClusters ) + mapByY( pX(:,J_M_vec(i)) , Z_plus_t(i)     , nClusters ) );                        
            
            error_M = error_M + 1 - similarityMargin;
            
            
        
            
            dX(I_M_vec(i),:) = dX(I_M_vec(i),:) -1/(length(I_M_vec) + length(I_C_vec)).*(W(:,Z_plus_t(i))- W(:,Z_minus_s{i}(1)))';
            dX(J_M_vec(i),:) = dX(J_M_vec(i),:) -1/(length(I_M_vec) + length(I_C_vec)).*(W(:,Z_plus_t(i))- W(:,Z_minus_s{i}(2)))';
            
            % dX = dX -1/(length(I_M_vec) + length(I_C_vec)).*(2*W(:,Z_plus_t(i))-  W(:,Z_minus_s{i}(1)) - W(:,Z_minus_s{i}(2))); 
            % -1/(length(I_M_vec) + length(I_C_vec))
        end
    end
    
    % find (Z_i^+(s), Z_j^+(s)) for (i,j)\in C^{violation}
    [C, Z_plus_s] = max( W' * ( pX(:,I_C_vec) + pX(:,J_C_vec) ) ); %Z_plus_s(i) = p
    % get statistic for the assignment
    [z_counts] = histc(Z_plus_s, 1: nClusters);
    [junk, index] = sort(z_counts, 'descend');
    % for ic =1: nClusters % check any cluster is less than a ratio
    %    if z_counts(ic) < ratio*numel(I_C_vec)
    % end
    idlist = find(junk<2);
    dset = setdiff(1: nClusters, index(idlist));
    
    if numel(dset) < nClusters    
        stop =1;
        temp=abs(W' * ( pX(:,I_C_vec) - pX(:,J_C_vec) ));
        [val, idx]= min(temp);
        available =ismember(idx, dset);
        chooseid = find(available);
        nums = length(chooseid);
        Z_plus_s(chooseid(1:min(2, nums))) = idlist(1);
        
    end
    
    error_C = 0;
    subGradCvio = zeros(dim * nClusters, 1);
    for i = 1 : length(I_C_vec)
        similarityMargin = W(:,Z_minus_t{i}(1))' * pX(:,I_C_vec(i)) + W(:,Z_minus_t{i}(2))' * pX(:,J_C_vec(i)) -...
                           W(:,Z_plus_s(i))' * ( pX(:,I_C_vec(i)) + pX(:,J_C_vec(i)) );
        if similarityMargin < 1
            subGradCvio = subGradCvio + ( mapByY( pX(:,I_C_vec(i)) , Z_plus_s(i)     , nClusters ) + mapByY( pX(:,J_C_vec(i)) , Z_plus_s(i)     , nClusters ) ) ...
                                      - ( mapByY( pX(:,I_C_vec(i)) , Z_minus_t{i}(1) , nClusters ) + mapByY( pX(:,J_C_vec(i)) , Z_minus_t{i}(2) , nClusters ) );
                                  
            error_C = error_C + 1 - similarityMargin;
            
        
            
            
            dX(I_C_vec(i),:) = dX(I_C_vec(i), :) -1/(length(I_M_vec) + length(I_C_vec)).*(W(:,Z_minus_t{i}(1))-W(:,Z_plus_s(i)))';
            dX(J_C_vec(i),:) = dX(J_C_vec(i), :) -1/(length(I_M_vec) + length(I_C_vec)).*(W(:,Z_minus_t{i}(2))-W(:,Z_plus_s(i)))';
            % dX = dX -1/(length(I_M_vec) + length(I_C_vec)).*(W(:,Z_minus_t{i}(1)) + W(:,Z_minus_t{i}(2)) - 2*W(:,Z_plus_s(i)));
            
        end
    end
       
    
    %if (~ismember(t,0:preIteration)) %-------------------------------------------    
        
        objFunVal = 0.5 * lambda * W_vec'* W_vec + ...
                    ( error_M + error_C ) ./ ( length(I_M_vec) + length(I_C_vec) ) + ...
                    cOne * error_NonMC ./ (sizeOfU*nClusters + eps);     
    % end %-------------------------------------------    
    
    learningRate = (1./lambda)./s;
    
    %
    if (ismember(t,0:preIteration))
        sumSubGrad = lambda * W_vec + ...
                     (subGradMvio + subGradCvio)./(length(I_M_vec) + length(I_C_vec));
    else    
        sumSubGrad = lambda * W_vec + ...
                     (subGradMvio + subGradCvio)./(length(I_M_vec) + length(I_C_vec)) + ...                     
                     cOne * subGradPvio ./ (sizeOfU*nClusters + eps);                 
    end
      
    
    % forward here
    i =1;
    w1probs = 1./(1 + exp(-([train_X ones(nPoints, 1)]* [network{i}.W; network{i}.bias_upW])));
    % back propagation here
    % compute the gradient for the original data
    if (ismember(t,0:preIteration))
        dW_vec = (subGradMvio + subGradCvio)./(length(I_M_vec) + length(I_C_vec));
    else
    
    dW_vec = (subGradMvio + subGradCvio)./(length(I_M_vec) + length(I_C_vec)) +...
        cOne * subGradPvio ./ (sizeOfU*nClusters + eps);
    end
    % dX = dX./(length(I_M_vec) + length(I_C_vec));
    % Ix1 = (dX*W_vec').*w1probs.*(1-w1probs); 
    % Ix1 = Ix1(:,1:end-1);
    Ix1 = dX.*w1probs.*(1-w1probs); 
    dvWh =  [train_X, ones(nPoints, 1)]'*Ix1;
    
    momentum = 0.8;
    dinc = -0.01 * dvWh; %momentum * vWh -0.01 * dvWh;
    vWh = vWh +  dinc;
    
    %grad = [dW_vec(:); dvWh(:)];
    grad = [sumSubGrad(:); dvWh(:)];
%     vWh  = [network{1}.W; network{1}.bias_upW];
%     vWhtemp  = [vWh(:)];
%     dvWhtemp = [dvWh(:)]; 
%     dvWh_L1 = pseudoGrad(vWhtemp,dvWhtemp, 4);
%     
%     grad = [sumSubGrad(:); dvWh_L1(:)];
    if flag 
        
        idx=1;
        network{idx}.W = vWh(1:size(network{idx}.W,1),:);
        network{idx}.bias_upW = vWh(size(network{idx}.W,1)+1,:);
    end
             
    newW_vec = W_vec - learningRate * sumSubGrad;
    
    newW_vec = min(1 , radius./norm(newW_vec)) * newW_vec;
            
    %///////////////////////////////////////////////////////////////////////////////////////////    
    % decide whether inner convergence has achieved
    %///////////////////////////////////////////////////////////////////////////////////////////
    if norm(newW_vec - W_vec) ./max( norm(newW_vec), norm(W_vec) ) <= innerTol | s > 5000%round(100./lambda)%500     
        innerConvergence = 1;
        %fprintf('Inner loop (extendedPEGASOS_tkde) converges in iteration s=%d.\n\n',s);
    else        
        %fprintf('Inner loop in s=%dth iteration...\n',s);
    end
    
    W_vec = newW_vec;
    
    s = s + 1;
    
% end  
                                       

%% Psuedo-gradient calculation
function [pGrad] = pseudoGrad(w,g, lambda)

if numel(lambda) < size(g,1)
lambda = lambda*ones(size(g));
end
pGrad = zeros(size(g));
pGrad(g < -lambda) = g(g < -lambda) + lambda(g < -lambda);
pGrad(g > lambda) = g(g > lambda) - lambda(g > lambda);
nonZero = w~=0 | lambda==0;
pGrad(nonZero) = g(nonZero) + lambda(nonZero).*sign(w(nonZero));

                                   