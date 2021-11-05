%% RETI DI CALCOLATORI: ESAME MULTIMEDIA

clear 
close all
clc  

%******************************************
%* modificare in seguito il nome del file *
%******************************************
namefile ='inputaudio2.data';

%Ho calcolato la frequenza di campionamento sapendo che a ogni pacchetto
%di 160 dati corrisponde a un intervallo di tempo complessivo di 0.02s.
%Pertanto il tempo di campionamento risulta Tc = 0.02/160 = 0.000125s. La
%frequenza di campionamento risulta quindi Fc = 1/Tc = 1/0.000125 = 8000Hz.

Fc = 8000;
codepointlength=strcat('int',num2str(8));   %leggo 8 bit per volta
x=zeros(1,1,'int8');    %dimensione iniziale posta a 1 perche' potenzialmente non so quanto e' lungo x(simulando di essere in real-time). Se possibile pero' e' molto piu' efficiente allocare prima.
fid = fopen(namefile,'r+');
i=0;
while ~feof(fid)
    codepoint = fread(fid,1,codepointlength);
    codepoint = int8(codepoint);
    i=i+1;
    if ~feof(fid)
        x(i) = codepoint; 
    end
end
fclose(fid);

%inizializzazione lunghezza pacchetto, numero di pacchetti(dato il vettore
%x), matrice che presenta un pacchetto ogni riga, vettore di risultato(conterra' 0 e 1)
i=1;
packet_length = 160;
num_packets=floor(length(x)/packet_length);
data = zeros(num_packets,packet_length);
array_result = zeros(1,num_packets);          

%inizializzazioni utili per la funzione (valori arbitrari iniziali)
threshold=0.8;
coeff=15;
max_estimate=10;
max_estimate_list=[];
sigma_estimate=10;
numero_pacchetti_incontrati=0;

%plot del segnale x originario
%t=(1/Fc)*(0:length(x)-1);
%figure;
%plot(t,abs(x),'r');
%grid on
%xlabel('Tempo [s]');
%ylabel('|x(t)|');

while i<num_packets
    y = x(i*packet_length:i*packet_length+packet_length-1);
    N = length(y);
    fc = Fc/N;
    Y = (1/Fc)*fft(y);
    Y = fftshift(Y); 
    f = fc*(-N/2:N/2-1);
    data(i,:) = abs(Y);
    massimo = max(abs(Y));
    %la funzione get_optimal_threshold restituisce un vettore di 5 elementi
    %(tutti e cinque i valori di ritorno vengono quindi aggiornati ad ogni iterazione).
    [threshold,max_estimate,max_estimate_list,sigma_estimate,numero_pacchetti_incontrati] = get_optimal_threshold(data(1:i,:),threshold,coeff,max_estimate,max_estimate_list,sigma_estimate,numero_pacchetti_incontrati);
    if(massimo > threshold)
        array_result(i) = 1;
    else
        array_result(i) = 0;
    end
    i = i+1;
end

%per ascoltare x filtrato, modifico x secondo il vettore array_result
for ii=1:num_packets
    if(array_result(ii)==0)
        for jj=1:packet_length
           x(ii*packet_length+jj)=0; 
        end
    end
end

%ascolto il segnale x filtrato
player = audioplayer(x,Fc);
play(player);

%plot del segnale x filtrato in funzione del tempo
%t=(1/Fc)*(0:length(x)-1);
%figure;
%plot(t,abs(x),'b');
%grid on
%xlabel('Tempo [s]');
%ylabel('|x_f_i_l_t_r_a_t_o(t)|');
% calcolo della tradformata di Fourier e plot della stessa (dell'ultimo pacchetto y incontrato)
%N = length(y);
%fc = Fc/N;
%Y = (1/Fc)*fft(y);
%Y = fftshift(Y);   
%f = fc*(-N/2:N/2-1);
%figure;
%plot(f,abs(Y),'r');
%grid on
%label('Frequenza [Hz]');
%ylabel('|Y(f)|');

%funzione per la stima della soglia (threshold) sotto la quale eliminare i pacchetti
function [threshold,max_estimate,max_estimate_list,sigma_estimate,numero_pacchetti_incontrati] = get_optimal_threshold(data,threshold,coeff,max_estimate,max_estimate_list,sigma_estimate,numero_pacchetti_incontrati)
    %il seguente ciclo for esegue sempre una sola iterazione. 
    for i=length(data(:,1)):length(data(:,1))
        this_pacchetto = data(i,:);
        this_sigma=std(this_pacchetto);
        this_max=max(this_pacchetto);
        if (numero_pacchetti_incontrati <=2)
            if (numero_pacchetti_incontrati ==0)
                if (this_max<threshold)
                    sigma_estimate = this_sigma;
                    max_estimate = this_max;
                    max_estimate_list(end+1) = this_max;
                    numero_pacchetti_incontrati = numero_pacchetti_incontrati + 1;
                end
            else
                if (abs(this_sigma-sigma_estimate) < (1+exp(-numero_pacchetti_incontrati))*coeff/100*sigma_estimate)
                    sigma_estimate = this_sigma;
                    max_estimate = this_max;
                    max_estimate_list(end+1) = this_max;
                    numero_pacchetti_incontrati = numero_pacchetti_incontrati + 1;
                end
            end
        else
            if (abs(this_sigma-sigma_estimate) < (1+exp(-numero_pacchetti_incontrati))*coeff/100*sigma_estimate)
                sigma_estimate = (numero_pacchetti_incontrati-1)/numero_pacchetti_incontrati * sigma_estimate + 1/numero_pacchetti_incontrati * this_sigma; 
                max_estimate = (numero_pacchetti_incontrati-1)/numero_pacchetti_incontrati * max_estimate + 1/numero_pacchetti_incontrati * this_max;
                max_estimate_list(end+1) = this_max;
                numero_pacchetti_incontrati = numero_pacchetti_incontrati + 1;                
            end
        end
    end
    if (length(max_estimate_list)>=2)
        threshold = max_estimate + 5*std(max_estimate_list); 
    else
        threshold = max_estimate;
    end
end
