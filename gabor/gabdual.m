function gd=gabdual(g,a,M,varargin)
%GABDUAL  Canonical dual window of Gabor frame
%   Usage:  gd=gabdual(g,a,M);
%           gd=gabdual(g,a,M,L);
%           gd=gabdual(g,a,M,L,lt);
%
%   Input parameters:
%         g     : Gabor window.
%         a     : Length of time shift.
%         M     : Number of channels.
%         L     : Length of window. (optional)
%         lt    : Lattice type (for non-separable lattices).
%   Output parameters:
%         gd : Canonical dual window.
%
%   `gabdual(g,a,M)` computes the canonical dual window of the discrete Gabor
%   frame with window *g* and parameters *a*, *M*.
%
%   The window *g* may be a vector of numerical values, a text string or a
%   cell array. See the help of |gabwin|_ for more details.
%
%   If the length of *g* is equal to *M*, then the input window is assumed
%   to be an FIR window. In this case, the canonical dual window also has
%   length of *M*. Otherwise the smallest possible transform length is chosen
%   as the window length.
%
%   `gabdual(g,a,M,L)` returns a window that is the dual window for a system
%   of length *L*. Unless the dual window is a FIR window, the dual window
%   will have length *L*.
%
%   `gabdual(g,a,M,[],lt)` or `gabdual(g,a,M,L,lt)` does the same for a
%   non-separable lattice specified by *lt*. Please see the help of
%   |matrix2latticetype|_ for a precise description of the parameter *lt*.
%
%   If $a>M$ then the dual window of the Gabor Riesz sequence with window
%   *g* and parameters *a* and *M* will be calculated.
%
%   See also:  gabtight, gabwin, fir2long, dgt

%   AUTHOR : Peter Soendergaard.
%   TESTING: TEST_DGT
%   REFERENCE: REF_GABDUAL.
  
%% ---------- Assert correct input.

if nargin<3
  error('%s: Too few input parameters.',upper(mfilename));
end;

definput.keyvals.L=[];
definput.keyvals.lt=[0 1];
definput.keyvals.nsalg=0;
[flags,kv,L,lt]=ltfatarghelper({'L','lt'},definput,varargin);

%% ------ step 2: Verify a, M and L
if isempty(L)
    if isnumeric(g)
        % Use the window length
        Ls=length(g);
    else
        % Use the smallest possible length
        Ls=1;
    end;

    % ----- step 2b : Verify a, M and get L from the window length ----------
    L=dgtlength(Ls,a,M,lt);

else

    % ----- step 2a : Verify a, M and get L

    Luser=dgtlength(L,a,M,lt);
    if Luser~=L
        error(['%s: Incorrect transform length L=%i specified. Next valid length ' ...
               'is L=%i. See the help of DGTLENGTH for the requirements.'],...
              upper(mfilename),L,Luser)
    end;

end;

%% ----- step 3 : Determine the window 

[g,info]=gabwin(g,a,M,L,lt,'callfun',upper(mfilename));

if L<info.gl
  error('%s: Window is too long.',upper(mfilename));
end;

R=size(g,2);
% -------- Are we in the Riesz sequence of in the frame case

scale=1;
if a>M*R
  % Handle the Riesz basis (dual lattice) case.
  % Swap a and M, and scale differently.
  scale=a/M;
  tmp=a;
  a=M;
  M=tmp;
end;

% -------- Compute ------------- 

if lt(2)==1
    % Rectangular case
    if (info.gl<=M) && (R==1)
        
        % FIR case
        N_win = ceil(info.gl/a);
        Lwin_new = N_win*a;
        if Lwin_new ~= info.gl
            g_new = fir2long(g,Lwin_new);
        else
            g_new = g;
        end
        weight = sum(reshape(abs(g_new).^2,a,N_win),2);
        
        gd = g_new./repmat(weight,N_win,1);
        gd = gd/M;
        if Lwin_new ~= info.gl
            gd = long2fir(gd,info.gl);
        end
        
    else
        
        % Long window case
        
        % Just in case, otherwise the call is harmless. 
        g=fir2long(g,L);
        
        gd=comp_gabdual_long(g,a,M)*scale;
        
    end;

else
    % Non-separable case
    g=fir2long(g,L);

    if (kv.nsalg==1) || (kv.nsalg==0 && lt(2)<=2) 
        
        mwin=comp_nonsepwin2multi(g,a,M,lt,L);
        
        gdfull=comp_gabdual_long(mwin,a*lt(2),M)*scale;
        
        % We need just the first vector
        gd=gdfull(:,1);
            
    else        
        
        [s0,s1,br] = shearfind(L,a,M,lt);        
        
        if s1 ~= 0
            g = comp_pchirp(L,s1).*g;
        end
        
        if s0 ~= 0
            g = ifft(comp_pchirp(L,-s0).*fft(g));
        end
        
        b=L/M;
        Mr = L/br;
        ar = a*b/br;
        
        gd=comp_gabdual_long(g,ar,Mr);
        
        if s0 ~= 0
            gd = ifft(comp_pchirp(L,s0).*fft(gd));
        end
        
        if s1 ~= 0
            gd = comp_pchirp(L,-s1).*gd;
        end

    end;

    if (info.gl<=M) && (R==1)
        gd=long2fir(gd,M);
    end;
        
end;
    
% --------- post process result -------

if isreal(g) && (lt(2)==1 || lt(2)==2)
  % If g is real and the lattice is either rectangular or quinqux, then
  % the output is known to be real.
  gd=real(gd);
end;

if info.wasrow
  gd=gd.';
end;
