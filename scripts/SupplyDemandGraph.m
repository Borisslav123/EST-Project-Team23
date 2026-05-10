
%% read raw data, time units, and graph
supplyData = readmatrix("data\Team23_supply.csv");
demandData = readmatrix("data\Team23_demand.csv");
price = readmatrix("data\settlement_prices_202412312300_202512312300_CET.csv");
price = price(:, end-3:end-2); %1rst column buying, 2nd selling


quart = 15*60;
hour = 3600;
day = 3600 * 24;
dt = quart/hour;


time = supplyData(:, 1)/hour;
supply = supplyData(:, 2);
demand = demandData(:, 2);

figure
plot(time, supply, '-b', time, demand, '-r')
xlabel('Time (h)');
ylabel('Power (MW)');
title('Power over time of a year')
legend('Supply', 'Demand')


%% Average and total power supply and demand

avgSupply = mean(supply);
avgDemand = mean(demand);

totalDemand = avgDemand*time(35040)*hour*10^6; %in Joule
totalSupply = avgSupply*time(35040)*hour*10^6; %in Joule

%% Average power per time of day

daySupply = reshape(supply, 96, []);
avgDaySupply = mean(daySupply, 2);
dayDemand = reshape(demand, 96, []);
avgDayDemand = mean(dayDemand, 2);

figure
plot(time(1:96), avgDaySupply, '-b', time(1:96), avgDayDemand, '-r')
xlabel('Time (h)')
ylabel('Power (W)')
title('Power over time average of a day')
legend('Supply', 'Demand')
xlim([0 24])

%% Average power per day

avgYearSupply = mean(daySupply, 1);
avgYearDemand = mean(dayDemand, 1);


figure
plot(1:365, avgYearSupply, '-b', 1:365, avgYearDemand, '-r' )
xlabel('Time (day)');
ylabel('Power (MW)');
title('Average power of a day over time of a year');
legend('Supply', 'Demand')
xlim([0 365])


%% Power difference

Difference = supply-demand;
maxDifference = max(Difference);
minDifference = min(Difference);
avgDifference = mean(Difference, 1);

figure
plot(time, Difference, '-b')
yline(avgDifference, '-k')
yline(0, '-r')
xlabel('Time (h)')
ylabel('Power difference (MW)')
legend('Difference in supply and demand', 'average Difference', '0-Value')
title('Power difference between supply and demand over a year')

%% Largest and most common idividual power shortages

pos = (Difference < 0);
d = diff([0; pos; 0]);
starts = [[find(d == 1);1] , [1;find(d == -1)]];
ends  = [[find(d == -1) - 1; 0],[find(d == 1); 35040]];

energy = [0;cumsum(Difference); 0] * 0.25;  
vShort = (energy(ends+1) - energy(starts));

[maxShortage, idx] = min(vShort(:, 1));
tStartMaxShort = time(starts(idx));
tEndMaxShort = time(ends(idx));

maxSurplus = max(vShort(:, 2));
totalDifference = sum(Difference);

figure
histogram(-vShort(:, 1))
xlabel('Power shortage (MWh)')
ylabel('Amount of shortages')

%% Energy storage without a maximum

[firstMaxAmount, firstMaxIdx] = max(energy(1:35040/2));
[minAmount, minIdx] = min(energy(firstMaxIdx:35041));
minIdx = minIdx + firstMaxIdx;
maxStorage = firstMaxAmount - minAmount;

fprintf('The maximum needed storage is %.2f MWh\n', maxStorage);

figure;
plot(time, energy(2:35041), '-b') 
hold on 
plot(time(firstMaxIdx:minIdx),energy(firstMaxIdx:minIdx), '-r', LineWidth=0.7);
plot(time(firstMaxIdx),energy(firstMaxIdx),"r+", MarkerSize=7, LineWidth=1)
plot(time(minIdx),energy(minIdx),"r+", MarkerSize=7, LineWidth=1)
xlim([0, max(time)])
ylim([0, max(energy)])

xlabel('Time (h)')
ylabel('Energy (MWh)')
title('Stored energy over time')
legend('Energy', 'Maximum discharge');
hold off

%% Energy storage with the maxium needed storage cap

maxNeedStoredEnergy = store(Difference, maxStorage);

figure
plot(time, maxNeedStoredEnergy, 'b-')
yline(maxStorage,'-y')
yline(0, 'Color',[0.5 0.5 0.5])

%% Energy storage with a constant buy/sell price

priceRatio = 0.5;
boughtSumVariable = 0.001; 
[~, sold, bought] = store(Difference, maxStorage);

storage = maxStorage;
totalBought = sum(bought);
totalSold = sum(sold);
boughtSum = totalBought - totalSold;

i = 0;
%finding the optimal amount of storage
while abs(boughtSum) > 0.0001
    
    storage = min(max(storage + boughtSumVariable*boughtSum,0), maxStorage);

    [storedEnergy, sold, bought] = store(Difference,storage);
    
    totalBought = sum(bought);
    totalSold = sum(sold);
    boughtSum = totalBought - totalSold*priceRatio;
    i = i + 1;
end

storageReduction = (maxStorage-storage)/maxStorage * 100;

fprintf('The constant storage is %.2fMWh which is a reduction of %.2f percent. \n', ...
   storage ,storageReduction);

figure;
plot(time, storedEnergy, '-b')
yline(storage,'-y')
yline(0, 'Color',[0.5 0.5 0.5])
xlim([0 max(time)])
ylim([min(storedEnergy)-1000 max(storedEnergy)+1000])

xlabel('Time (h)')
ylabel('Energy (MWh)')
title('Stored energy over time')
legend('Stored energy', 'Maximum storage')


%% Energy storage with dynamic pricing

[~, sold, bought] = store(Difference, maxStorage);

storage = maxStorage;
totalBought = sum(bought.*price(:, 1));
totalSold = sum(sold.*price(:, 2));
boughtSum = totalBought - totalSold;
boughtSumVariable = 0.00001; 

i = 0;
%finding the optimal amount of storage
while abs(boughtSum) > 0.0001
    
    storage = min(storage + boughtSumVariable*boughtSum, maxStorage);
   
    if storage < 0 
        storage = 0;
    end
        
    [storedEnergy, sold, bought] = store(Difference, storage);
    
    totalBought = sum(bought.*price(:, 1));
    totalSold = sum(sold.*price(:, 2));
    boughtSum = totalBought - totalSold;
    i = i + 1;
end


storageReduction = (maxStorage-storage)/maxStorage * 100;

fprintf('The dynamic storage is %.2fMWh which is a reduction of %.2f percent. \n', ...
   storage ,storageReduction);

figure;
plot(time, storedEnergy, '-b')
yline(storage,'-y')
yline(0, 'Color',[0.5 0.5 0.5])
xlim([0 max(time)])
ylim([min(storedEnergy)-1000 max(storedEnergy)+1000])

xlabel('Time (h)')
ylabel('Energy (MWh)')
title('Stored energy over time')
legend('Stored energy', 'Maximum storage')


%% -Functions-------------------------------------------------------------

function [eStored, eSold, eBought] = store(pDiff, storage)

% Function that describes the amount of energy that is stored, sold and
% bought over a period of time.
%
% pDiff: the power difference of supply and demand over a period of time.
% storage: the maximum amount of energy that can be stored.
%
% returns: 
% eStored: energy that is stored.
% eSold: energy that is sold.
% eBought: energy that is bought.
    k = numel(pDiff);
    eSum = 0; 
    eStored = zeros(k, 1);
    eSold = zeros(k, 1);
    eBought= zeros(k, 1);


    for n = 1:k
        eSum = eSum + pDiff(n)*0.25;
        if eSum > storage
            eSold(n) = eSum-storage;
            eSum = storage;
            
        elseif eSum < 0
            eBought(n) = -eSum;
            eSum = 0;  
        end
    eStored(n) = eSum;
    end 
end





