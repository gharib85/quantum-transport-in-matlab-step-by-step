function currents=sc_iv_curve(voltages, mol_H, extends, kt)
%% This function output an selfconsistent i-v curve of a transport model including
%% electrodes and local states, the iv curve is obtained from the
%% integration of transmission coefficients with electrostatic field
%% selfconsistency 

%% input requirement: 
%% voltages : vector of bias voltage
%% mol_H: a model hamiltonian of the central system
%% extends: the enviroment of the 'mol_H', including electrodes and local states whose number is not limited.
%%          each cell element of 'extends' is a local state or electrode with its members defined by the following.
%%          part_type:  1 for electrode, 0 for local state
%%          epsilon:   onsite energy
%%          coupling:  vector of the coupling hamiltonian with the molecule
%%          coupling_index : index of the coupling, meaning to which orbital or grid it couples with.
%%          sigma:  selfenergy, pure imaginary matrix with the same dimension as 'epsilon'
%%          fermi: fermi level of the electrode, not useful for local state

%% 宽带宽近似： sigma 与能量无关

%% calling sample:
% h0 = 0;
% t0 = -1.0;
% H0 = [h0,t0,0,0,0; t0,h0,t0,0,0; 0,t0,h0,t0,0; 0,0,t0,h0,t0; 0,0,0,t0,h0];
% % 电极在后， 第二个 coupling _index 为
% extends = {
%     struct('part_type', 0, 'epsilon', 0, 'coupling', 0.1, 'coupling_index', 5, 'sigma', 0, 'fermi', 2.3),
%     struct('part_type', 1, 'epsilon', 0, 'coupling', 0.1, 'coupling_index', 1, 'sigma', .1*1.j, 'fermi', 2.3), 
%     struct('part_type', 1, 'epsilon', 0, 'coupling', 0.1, 'coupling_index', 5, 'sigma', .1*1.j, 'fermi', 2.3)
% }
% 
% iv_curve([0.1, 0.2], H0, extends)


n0 = length(mol_H);
N = length(extends);
H = zeros(n0+N, n0+N);

nlead = 0;
for i=1:N
    if extends{i}.part_type == 1
        nlead = nlead+1;
    end
end

Sigma = zeros([nlead, n0+N-nlead, n0+N-nlead]);
Gamma = zeros([nlead, n0+N-nlead, n0+N-nlead]);

H(1:n0,1:n0) = mol_H;
ilead = 0;
for i = 1:N
    H(n0+i, n0+i) = extends{i}.epsilon;
    ind = extends{i}.coupling_index;
    H(ind, n0+i) = extends{i}.coupling';
    H(n0+i, ind) = extends{i}.coupling;
    if extends{i}.part_type == 1
        ilead = ilead + 1;
        Sigma(ilead,ind,ind) = Sigma(ilead,ind,ind) + extends{i}.sigma;         
    end   
end

for i =1:nlead
    sigma = squeeze(Sigma(i,:,:));
    Gamma(i,:,:) = 1.j*(sigma - sigma');
end

H = H(1:n0+N-nlead,1:n0+N-nlead);

maxv = max(abs(voltages));
fermi = extends{1}.fermi;
NE = 1001;
energies = linspace(fermi-maxv/2-8, fermi+maxv/2+3, NE);
eta = 1e-6;
S = eye(n0+N-nlead, n0+N-nlead);
T = zeros(1, NE);

nv = length(voltages);
currents = zeros(1, nv);
dE = energies(2) - energies(1);

sigmal = squeeze(Sigma(1,:,:));
sigmar = squeeze(Sigma(2,:,:));

H0 = H;

for i = 1:nv
    fprintf('voltage = %f\n', voltages(i)); 
    H = get_selfconsistent_hamiltonian(S, H0, Sigma, voltages(i), fermi, kt);

    for k=1:NE
        G = inv((energies(k)+1j*eta)*S-H-sigmal-sigmar);
        T(k) = real(trace(squeeze(Gamma(1,:,:))*G*squeeze(Gamma(2,:,:))*G')); % fisher lee formula
    end
    
    factors = fermidistribution(energies, fermi+voltages(i)/2, 0) - fermidistribution(energies, fermi-voltages(i)/2, 0);
    currents(i) = sum(T.*factors)*dE;
end

end