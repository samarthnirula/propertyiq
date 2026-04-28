#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

using namespace std;

struct ZipCodeData {
    string zipCode;
    string county;
    string marketTier;
    string regionBucket;
    int urbanCoreFlag = 0;

    double latitude = 0.0;
    double longitude = 0.0;
    double avgPropertyValue = 0.0;

    double medianIncome = 0.0;
    double medianRent = 0.0;
    double populationChangePct = 0.0;
    double ownerSharePct = 0.0;
    double crimeRate = 0.0;

    double zhvi1yChangePct = 0.0;
    double zhvi5yChangePct = 0.0;
    double priceToRentRatio = 0.0;
    double listingCount = 0.0;
    double averageSqft = 0.0;
    int wealthCluster = 0;
int growthCluster = 0;
int rentCluster = 0;
string clusterKey;
};

struct NeighborRecord {
    string zipCode;
    string county;
    string marketTier;
    string regionBucket;
    int urbanCoreFlag = 0;
    double scoreDistance = 0.0;
    double propertyValue = 0.0;
    string clusterKey;
};

struct FeatureStats {
    double minVal = numeric_limits<double>::max();
    double maxVal = numeric_limits<double>::lowest();
};

static string trim(const string& s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == string::npos) return "";
    size_t end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

static string lowerCopy(string s) {
    transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
        return static_cast<char>(tolower(c));
    });
    return s;
}

static vector<string> splitCsvLine(const string& line) {
    vector<string> result;
    string current;
    bool inQuotes = false;

    for (char c : line) {
        if (c == '"') {
            inQuotes = !inQuotes;
        } else if (c == ',' && !inQuotes) {
            result.push_back(trim(current));
            current.clear();
        } else {
            current.push_back(c);
        }
    }

    result.push_back(trim(current));
    return result;
}

static double safeParseDouble(const string& s, double fallback = 0.0) {
    try {
        if (s.empty()) return fallback;
        return stod(s);
    } catch (...) {
        return fallback;
    }
}

static int safeParseInt(const string& s, int fallback = 0) {
    try {
        if (s.empty()) return fallback;
        return stoi(s);
    } catch (...) {
        return fallback;
    }
}

static double deg2rad(double deg) {
    return deg * M_PI / 180.0;
}

static double haversineMiles(double lat1, double lon1, double lat2, double lon2) {
    constexpr double EARTH_RADIUS_MILES = 3958.8;

    double dLat = deg2rad(lat2 - lat1);
    double dLon = deg2rad(lon2 - lon1);

    double a = pow(sin(dLat / 2), 2) +
               cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * pow(sin(dLon / 2), 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return EARTH_RADIUS_MILES * c;
}

static double normalize(double value, const FeatureStats& stats) {
    if (stats.maxVal <= stats.minVal) return 0.0;
    return (value - stats.minVal) / (stats.maxVal - stats.minVal);
}

static string zipPrefix2(const string& zipCode) {
    if (zipCode.size() >= 2) return zipCode.substr(0, 2);
    return "";
}

static string zipPrefix3(const string& zipCode) {
    if (zipCode.size() >= 3) return zipCode.substr(0, 3);
    return "";
}

static int tierRank(const string& tier) {
    string t = lowerCopy(tier);
    if (t == "low") return 0;
    if (t == "mid") return 1;
    if (t == "high") return 2;
    if (t == "premium") return 3;
    if (t == "luxury") return 4;
    if (t == "ultra_luxury") return 5;
    return 1;
}

static int wealthBucket(double price) {
    if (price >= 1500000) return 5; // ultra wealthy
    if (price >= 800000) return 4;  // wealthy
    if (price >= 400000) return 3;  // upper middle
    if (price >= 200000) return 2;  // middle
    return 1;                       // affordable
}

static bool marketTierCompatible(const string& a, const string& b) {
    int diff = abs(tierRank(a) - tierRank(b));

    if (tierRank(a) >= 4 || tierRank(b) >= 4) return diff == 0;
    if (tierRank(a) >= 3 || tierRank(b) >= 3) return diff <= 1;
    return diff <= 1;
}
static int growthBucket(double pct) {
    if (pct >= 25.0) return 5;
    if (pct >= 15.0) return 4;
    if (pct >= 7.0) return 3;
    if (pct >= 0.0) return 2;
    return 1;
}

static int rentBucket(double rent) {
    if (rent >= 3500) return 5;
    if (rent >= 2500) return 4;
    if (rent >= 1800) return 3;
    if (rent >= 1200) return 2;
    return 1;
}

static string buildClusterKey(const ZipCodeData& z) {
    return to_string(wealthBucket(z.avgPropertyValue)) + "_" +
           to_string(growthBucket(z.zhvi1yChangePct)) + "_" +
           to_string(rentBucket(z.medianRent)) + "_" +
           z.regionBucket + "_" +
           to_string(z.urbanCoreFlag);
}

static bool sameCluster(const ZipCodeData& a, const ZipCodeData& b) {
    return buildClusterKey(a) == buildClusterKey(b);
}

static bool clusterCompatible(const ZipCodeData& a, const ZipCodeData& b) {
    int wDiff = abs(wealthBucket(a.avgPropertyValue) - wealthBucket(b.avgPropertyValue));
    int gDiff = abs(growthBucket(a.zhvi1yChangePct) - growthBucket(b.zhvi1yChangePct));
    int rDiff = abs(rentBucket(a.medianRent) - rentBucket(b.medianRent));

    return wDiff <= 1 && gDiff <= 1 && rDiff <= 1;
}

static unordered_map<string, double> loadCrimeRates(const string& crimeFilePath) {
    unordered_map<string, double> crimeByCounty;
    ifstream file(crimeFilePath);
    if (!file.is_open()) {
        cerr << "Warning: Could not open crime file: " << crimeFilePath << endl;
        return crimeByCounty;
    }

    string line;
    while (getline(file, line)) {
        line = trim(line);
        if (line.empty()) continue;

        size_t commaPos = line.find(',');
        if (commaPos == string::npos) continue;

        string county = lowerCopy(trim(line.substr(0, commaPos)));
        string valueStr = trim(line.substr(commaPos + 1));
        double crimeRate = safeParseDouble(valueStr, 0.0);

        if (!county.empty()) {
            crimeByCounty[county] = crimeRate;
        }
    }

    return crimeByCounty;
}

static vector<ZipCodeData> loadDataset(
    const string& datasetFilePath,
    const unordered_map<string, double>& crimeByCounty
) {
    vector<ZipCodeData> dataset;

    ifstream file(datasetFilePath);
    if (!file.is_open()) {
        cerr << "Error: Could not open dataset file: " << datasetFilePath << endl;
        return dataset;
    }

    string headerLine;
    if (!getline(file, headerLine)) {
        cerr << "Error: Dataset file is empty." << endl;
        return dataset;
    }

    vector<string> headers = splitCsvLine(headerLine);
    unordered_map<string, size_t> idx;

    for (size_t i = 0; i < headers.size(); ++i) {
        idx[lowerCopy(headers[i])] = i;
    }

    auto getField = [&](const vector<string>& row, const string& key) -> string {
        auto it = idx.find(lowerCopy(key));
        if (it == idx.end()) return "";
        if (it->second >= row.size()) return "";
        return row[it->second];
    };

    string line;
    while (getline(file, line)) {
        if (trim(line).empty()) continue;

        vector<string> row = splitCsvLine(line);

        ZipCodeData z;
        z.zipCode = getField(row, "zip_code");
        z.county = lowerCopy(getField(row, "county"));
        z.marketTier = lowerCopy(getField(row, "market_tier"));
        z.regionBucket = lowerCopy(getField(row, "region_bucket"));
        z.urbanCoreFlag = safeParseInt(getField(row, "urban_core_flag"), 0);

        z.latitude = safeParseDouble(getField(row, "latitude"));
        z.longitude = safeParseDouble(getField(row, "longitude"));
        z.avgPropertyValue = safeParseDouble(getField(row, "avg_property_value"));

        z.medianIncome = safeParseDouble(getField(row, "median_income"));
        z.medianRent = safeParseDouble(getField(row, "median_rent"));
        z.populationChangePct = safeParseDouble(getField(row, "population_change_pct"));
        z.ownerSharePct = safeParseDouble(getField(row, "owner_share_pct"));
        z.zhvi1yChangePct = safeParseDouble(getField(row, "zhvi_1y_change_pct"));
        z.zhvi5yChangePct = safeParseDouble(getField(row, "zhvi_5y_change_pct"));
        z.priceToRentRatio = safeParseDouble(getField(row, "price_to_rent_ratio"));
        z.listingCount = safeParseDouble(getField(row, "listing_count"));
        z.averageSqft = safeParseDouble(getField(row, "average_sqft"));

        auto crimeIt = crimeByCounty.find(z.county);
        if (crimeIt != crimeByCounty.end()) {
            z.crimeRate = crimeIt->second;
        }

        if (!z.zipCode.empty() && z.avgPropertyValue > 0.0) {
            dataset.push_back(z);
        }
    }

    return dataset;
}

static unordered_map<string, FeatureStats> computeFeatureStats(const vector<ZipCodeData>& dataset) {
    unordered_map<string, FeatureStats> statsMap = {
        {"income", {}},
        {"rent", {}},
        {"pop", {}},
        {"owner", {}},
        {"crime", {}},
        {"trend1y", {}},
        {"trend5y", {}},
        {"ptr", {}},
        {"listings", {}},
        {"sqft", {}}
    };

    for (const auto& z : dataset) {
        statsMap["income"].minVal = min(statsMap["income"].minVal, z.medianIncome);
        statsMap["income"].maxVal = max(statsMap["income"].maxVal, z.medianIncome);

        statsMap["rent"].minVal = min(statsMap["rent"].minVal, z.medianRent);
        statsMap["rent"].maxVal = max(statsMap["rent"].maxVal, z.medianRent);

        statsMap["pop"].minVal = min(statsMap["pop"].minVal, z.populationChangePct);
        statsMap["pop"].maxVal = max(statsMap["pop"].maxVal, z.populationChangePct);

        statsMap["owner"].minVal = min(statsMap["owner"].minVal, z.ownerSharePct);
        statsMap["owner"].maxVal = max(statsMap["owner"].maxVal, z.ownerSharePct);

        statsMap["crime"].minVal = min(statsMap["crime"].minVal, z.crimeRate);
        statsMap["crime"].maxVal = max(statsMap["crime"].maxVal, z.crimeRate);

        statsMap["trend1y"].minVal = min(statsMap["trend1y"].minVal, z.zhvi1yChangePct);
        statsMap["trend1y"].maxVal = max(statsMap["trend1y"].maxVal, z.zhvi1yChangePct);

        statsMap["trend5y"].minVal = min(statsMap["trend5y"].minVal, z.zhvi5yChangePct);
        statsMap["trend5y"].maxVal = max(statsMap["trend5y"].maxVal, z.zhvi5yChangePct);

        statsMap["ptr"].minVal = min(statsMap["ptr"].minVal, z.priceToRentRatio);
        statsMap["ptr"].maxVal = max(statsMap["ptr"].maxVal, z.priceToRentRatio);

        statsMap["listings"].minVal = min(statsMap["listings"].minVal, z.listingCount);
        statsMap["listings"].maxVal = max(statsMap["listings"].maxVal, z.listingCount);

        statsMap["sqft"].minVal = min(statsMap["sqft"].minVal, z.averageSqft);
        statsMap["sqft"].maxVal = max(statsMap["sqft"].maxVal, z.averageSqft);
    }

    return statsMap;
}

static double featureDiff(double target, double row, const FeatureStats& stats) {
    return fabs(normalize(target, stats) - normalize(row, stats));
}

static double completenessPenalty(const ZipCodeData& row) {
    double penalty = 0.0;
    if (row.medianIncome <= 0) penalty += 0.10;
    if (row.medianRent <= 0) penalty += 0.10;
    if (row.ownerSharePct <= 0) penalty += 0.05;
    if (row.averageSqft <= 0) penalty += 0.05;
    if (row.listingCount <= 0) penalty += 0.05;
    if (row.marketTier.empty()) penalty += 0.03;
    if (row.regionBucket.empty()) penalty += 0.03;
    return penalty;
}

static double listingPenaltyMultiplier(const ZipCodeData& row) {
    if (row.listingCount <= 0) return 0.70;
    if (row.listingCount < 3) return 0.75;
    if (row.listingCount < 5) return 0.82;
    if (row.listingCount < 8) return 0.90;
    return 1.0;
}

static bool isPriceTierCompatible(double targetPrice, double neighborPrice) {
    if (targetPrice <= 0 || neighborPrice <= 0) return true;

    double ratio = neighborPrice / targetPrice;

    if (ratio < 0.50 || ratio > 2.00) return false;

    if (targetPrice < 150000) return ratio >= 0.75 && ratio <= 1.30;
    if (targetPrice < 250000) return ratio >= 0.70 && ratio <= 1.40;
    if (targetPrice < 500000) return ratio >= 0.60 && ratio <= 1.55;
    if (targetPrice < 1000000) return ratio >= 0.55 && ratio <= 1.70;
    if (targetPrice < 2000000) return ratio >= 0.60 && ratio <= 1.50;
    return ratio >= 0.70 && ratio <= 1.35;
}

static bool passesGeoCap(const ZipCodeData& target, const ZipCodeData& row) {
    if (target.latitude == 0.0 || target.longitude == 0.0 ||
        row.latitude == 0.0 || row.longitude == 0.0) {
        return true;
    }

    double miles = haversineMiles(target.latitude, target.longitude, row.latitude, row.longitude);

    if (target.urbanCoreFlag == 1) return miles <= 45.0;
    if (tierRank(target.marketTier) >= 4) return miles <= 90.0;
    if (target.avgPropertyValue < 150000) return miles <= 100.0;
    if (target.avgPropertyValue < 250000) return miles <= 140.0;
    if (target.avgPropertyValue < 500000) return miles <= 180.0;
    return miles <= 220.0;
}

static double computeSimilarityDistance(
    const ZipCodeData& target,
    const ZipCodeData& row,
    const unordered_map<string, FeatureStats>& statsMap
) {
    double geo = 0.0;
    if (target.latitude != 0.0 && target.longitude != 0.0 &&
        row.latitude != 0.0 && row.longitude != 0.0) {
        geo = haversineMiles(target.latitude, target.longitude, row.latitude, row.longitude);
    }

    double incomeDiff = featureDiff(target.medianIncome, row.medianIncome, statsMap.at("income"));
    double rentDiff = featureDiff(target.medianRent, row.medianRent, statsMap.at("rent"));
    double popDiff = featureDiff(target.populationChangePct, row.populationChangePct, statsMap.at("pop"));
    double ownerDiff = featureDiff(target.ownerSharePct, row.ownerSharePct, statsMap.at("owner"));
    double crimeDiff = featureDiff(target.crimeRate, row.crimeRate, statsMap.at("crime"));

    double trend1yDiff = featureDiff(target.zhvi1yChangePct, row.zhvi1yChangePct, statsMap.at("trend1y"));
    double trend5yDiff = featureDiff(target.zhvi5yChangePct, row.zhvi5yChangePct, statsMap.at("trend5y"));
    double ptrDiff = featureDiff(target.priceToRentRatio, row.priceToRentRatio, statsMap.at("ptr"));
    double listingsDiff = featureDiff(target.listingCount, row.listingCount, statsMap.at("listings"));
    double sqftDiff = featureDiff(target.averageSqft, row.averageSqft, statsMap.at("sqft"));

    double countyBonus = (target.county == row.county && !target.county.empty()) ? -3.0 : 0.0;
    double regionBonus = (target.regionBucket == row.regionBucket && !target.regionBucket.empty()) ? -5.0 : 0.0;
    double tierBonus = (target.marketTier == row.marketTier && !target.marketTier.empty()) ? -3.0 : 0.0;
    double urbanBonus = (target.urbanCoreFlag == row.urbanCoreFlag) ? -2.0 : 0.0;
    double prefix3Bonus =
        (zipPrefix3(target.zipCode) == zipPrefix3(row.zipCode) &&
         !zipPrefix3(target.zipCode).empty()) ? -1.2 : 0.0;

    int targetBucket = wealthBucket(target.avgPropertyValue);
    int rowBucket = wealthBucket(row.avgPropertyValue);
    double wealthBonus = (targetBucket == rowBucket) ? -4.0 : -1.5;
    double clusterBonus = sameCluster(target, row) ? -10.0 :
                      (clusterCompatible(target, row) ? -4.0 : 6.0);

    double urbanMismatchPenalty = (target.urbanCoreFlag != row.urbanCoreFlag) ? 6.0 : 0.0;

    double score =
        (geo * 0.11) +
        (incomeDiff * 20.0 * 0.16) +
        (rentDiff * 20.0 * 0.16) +
        (popDiff * 20.0 * 0.06) +
        (ownerDiff * 20.0 * 0.05) +
        (crimeDiff * 20.0 * 0.05) +
        (trend1yDiff * 20.0 * 0.12) +
        (trend5yDiff * 20.0 * 0.12) +
        (ptrDiff * 20.0 * 0.08) +
        (listingsDiff * 20.0 * 0.03) +
        (sqftDiff * 20.0 * 0.06) +
        countyBonus +
        regionBonus +
        tierBonus +
        urbanBonus +
        prefix3Bonus +
wealthBonus +
clusterBonus +
urbanMismatchPenalty +
        (completenessPenalty(row) * 20.0);

    return score;
}

static double weightedMedian(vector<pair<double, double>> vw) {
    if (vw.empty()) return 0.0;

    sort(vw.begin(), vw.end(), [](const auto& a, const auto& b) {
        return a.first < b.first;
    });

    double totalWeight = 0.0;
    for (const auto& x : vw) totalWeight += x.second;

    double running = 0.0;
    for (const auto& x : vw) {
        running += x.second;
        if (running >= totalWeight / 2.0) return x.first;
    }

    return vw.back().first;
}

static double averageForCounty(const vector<ZipCodeData>& dataset, const ZipCodeData& target) {
    double sum = 0.0;
    int count = 0;
    for (const auto& row : dataset) {
        if (row.county == target.county && row.marketTier == target.marketTier) {
            sum += row.avgPropertyValue;
            count++;
        }
    }
    return count > 0 ? sum / count : 0.0;
}

static double averageForRegion(const vector<ZipCodeData>& dataset, const ZipCodeData& target) {
    double sum = 0.0;
    int count = 0;
    for (const auto& row : dataset) {
        if (row.regionBucket == target.regionBucket &&
            marketTierCompatible(row.marketTier, target.marketTier)) {
            sum += row.avgPropertyValue;
            count++;
        }
    }
    return count > 0 ? sum / count : 0.0;
}

static double predictPropertyValueWeightedKNN(
    const vector<ZipCodeData>& dataset,
    const ZipCodeData& target,
    int k,
    vector<NeighborRecord>& neighborsOut,
    double& confidenceScoreOut
) {
    if (dataset.empty()) throw runtime_error("Dataset is empty.");
    if (k <= 0) throw runtime_error("k must be greater than 0.");

    auto statsMap = computeFeatureStats(dataset);

    vector<NeighborRecord> neighbors;
    neighbors.reserve(dataset.size());

    for (const auto& row : dataset) {
        if (row.avgPropertyValue <= 0.0) continue;
        if (row.zipCode == target.zipCode) continue;

        int targetBucket = wealthBucket(target.avgPropertyValue);
        int neighborBucket = wealthBucket(row.avgPropertyValue);

        if (abs(targetBucket - neighborBucket) > 1) continue;
        if (!isPriceTierCompatible(target.avgPropertyValue, row.avgPropertyValue)) continue;
        if (!passesGeoCap(target, row)) continue;
if (!marketTierCompatible(target.marketTier, row.marketTier)) continue;
if (!clusterCompatible(target, row) && !sameCluster(target, row)) continue;

        if (target.urbanCoreFlag == 1 && row.urbanCoreFlag != 1) continue;
        if (tierRank(target.marketTier) >= 4 && tierRank(row.marketTier) < 4) continue;

        double dist = computeSimilarityDistance(target, row, statsMap);

neighbors.push_back({
    row.zipCode,
    row.county,
    row.marketTier,
    row.regionBucket,
    row.urbanCoreFlag,
    dist,
    row.avgPropertyValue,
    buildClusterKey(row)
});
    }

    if (neighbors.empty()) {
        throw runtime_error("No valid neighbors found after filtering.");
    }

sort(neighbors.begin(), neighbors.end(), [&](const NeighborRecord& a, const NeighborRecord& b) {
    bool aSame = (a.clusterKey == buildClusterKey(target));
    bool bSame = (b.clusterKey == buildClusterKey(target));

    if (aSame != bSame) return aSame > bSame;
    return a.scoreDistance < b.scoreDistance;
});

    int cutoff = static_cast<int>(neighbors.size() * 0.9);
    neighbors.resize(max(5, cutoff));

    int actualK = min(k, static_cast<int>(neighbors.size()));

    double weightedLogSum = 0.0;
    double totalWeight = 0.0;
    vector<pair<double, double>> logValueWeights;

    neighborsOut.clear();
    for (int i = 0; i < actualK; ++i) {
        const auto& n = neighbors[i];

        double weight = 1.0 / (pow(max(0.000001, n.scoreDistance), 2.5) + 1e-6);

        auto it = find_if(dataset.begin(), dataset.end(), [&](const ZipCodeData& z) {
            return z.zipCode == n.zipCode;
        });
        if (it != dataset.end()) {
            weight *= listingPenaltyMultiplier(*it);
        }

        double logPrice = log(max(1.0, n.propertyValue));

        weightedLogSum += weight * logPrice;
        totalWeight += weight;
        logValueWeights.push_back({logPrice, weight});
        neighborsOut.push_back(n);
    }

    if (totalWeight == 0.0) {
        throw runtime_error("Total weight is zero.");
    }

    double weightedMeanLog = weightedLogSum / totalWeight;
    double weightedMedianLog = weightedMedian(logValueWeights);
    double knnPrediction = exp((0.65 * weightedMeanLog) + (0.35 * weightedMedianLog));

    double countyAvg = averageForCounty(dataset, target);
    double regionAvg = averageForRegion(dataset, target);

    double finalPrediction = knnPrediction;

    if (countyAvg > 0 && regionAvg > 0) {
        finalPrediction = (0.75 * knnPrediction) + (0.15 * countyAvg) + (0.10 * regionAvg);
    } else if (countyAvg > 0) {
        finalPrediction = (0.82 * knnPrediction) + (0.18 * countyAvg);
    } else if (regionAvg > 0) {
        finalPrediction = (0.88 * knnPrediction) + (0.12 * regionAvg);
    }

double variance = 0.0;
int sameClusterCount = 0;

for (int i = 0; i < actualK; ++i) {
    double diff = neighbors[i].propertyValue - finalPrediction;
    variance += diff * diff;

    if (neighbors[i].clusterKey == buildClusterKey(target)) {
        sameClusterCount++;
    }
}
variance /= actualK;

double stddev = sqrt(variance);
double spreadScore = max(0.0, 1.0 - (stddev / max(1.0, finalPrediction)));
double clusterScore = static_cast<double>(sameClusterCount) / max(1, actualK);
double kScore = min(1.0, actualK / 7.0);

// weighted confidence: spread + same-cluster quality + enough comps
confidenceScoreOut =
    (0.55 * spreadScore) +
    (0.30 * clusterScore) +
    (0.15 * kScore);

confidenceScoreOut = max(0.0, min(1.0, confidenceScoreOut));

    return finalPrediction;
}

static void printUsage() {
    cerr << "Usage:\n";
    cerr << "  ./predictor <dataset_csv> <crime_txt> <zip_code> <county> <lat> <lon> <median_income> <median_rent> <population_change_pct> <owner_share_pct> <k> [zhvi_1y_change_pct] [zhvi_5y_change_pct] [price_to_rent_ratio] [listing_count] [average_sqft] [avg_property_value] [market_tier] [region_bucket] [urban_core_flag]\n";
}

int main(int argc, char* argv[]) {
    try {
        if (argc < 12) {
            printUsage();
            return 1;
        }

        string datasetPath = argv[1];
        string crimePath = argv[2];

        ZipCodeData target;
        target.zipCode = argv[3];
        target.county = lowerCopy(argv[4]);
        target.latitude = safeParseDouble(argv[5]);
        target.longitude = safeParseDouble(argv[6]);
        target.medianIncome = safeParseDouble(argv[7]);
        target.medianRent = safeParseDouble(argv[8]);
        target.populationChangePct = safeParseDouble(argv[9]);
        target.ownerSharePct = safeParseDouble(argv[10]);
        int k = stoi(argv[11]);

        if (argc > 12) target.zhvi1yChangePct = safeParseDouble(argv[12]);
        if (argc > 13) target.zhvi5yChangePct = safeParseDouble(argv[13]);
        if (argc > 14) target.priceToRentRatio = safeParseDouble(argv[14]);
        if (argc > 15) target.listingCount = safeParseDouble(argv[15]);
        if (argc > 16) target.averageSqft = safeParseDouble(argv[16]);
        if (argc > 17) target.avgPropertyValue = safeParseDouble(argv[17]);
        if (argc > 18) target.marketTier = lowerCopy(argv[18]);
        if (argc > 19) target.regionBucket = lowerCopy(argv[19]);
        if (argc > 20) target.urbanCoreFlag = safeParseInt(argv[20], 0);

        auto crimeByCounty = loadCrimeRates(crimePath);
        auto crimeIt = crimeByCounty.find(target.county);
        if (crimeIt != crimeByCounty.end()) {
            target.crimeRate = crimeIt->second;
        }

        vector<ZipCodeData> dataset = loadDataset(datasetPath, crimeByCounty);
        if (dataset.empty()) {
            cerr << "{\"error\":\"Dataset could not be loaded or is empty.\"}\n";
            return 1;
        }

        vector<NeighborRecord> topNeighbors;
        double confidenceScore = 0.0;
        double predictedValue = predictPropertyValueWeightedKNN(
            dataset,
            target,
            k,
            topNeighbors,
            confidenceScore
        );

        cout << fixed << setprecision(2);
        cout << "{";
        cout << "\"zip_code\":\"" << target.zipCode << "\",";
        cout << "\"county\":\"" << target.county << "\",";
        cout << "\"predicted_average_property_value\":" << predictedValue << ",";
        cout << "\"k_used\":" << min(k, static_cast<int>(topNeighbors.size())) << ",";
        cout << "\"crime_rate\":" << target.crimeRate << ",";
        cout << "\"confidence_score\":" << confidenceScore << ",";
        // Compute similarity scores: invert and normalize so best match = 100%
        double minScore = topNeighbors.empty() ? 0.0 : topNeighbors[0].scoreDistance;
        double maxScore = minScore;
        for (const auto& n : topNeighbors) {
            minScore = min(minScore, n.scoreDistance);
            maxScore = max(maxScore, n.scoreDistance);
        }
        double scoreRange = maxScore - minScore;

        cout << "\"neighbors\":[";
        for (size_t i = 0; i < topNeighbors.size(); ++i) {
            const auto& n = topNeighbors[i];
            double simPct = (scoreRange > 1e-10)
                ? ((maxScore - n.scoreDistance) / scoreRange * 100.0)
                : 100.0;
            simPct = max(0.0, min(100.0, simPct));
            cout << "{";
            cout << "\"zip_code\":\"" << n.zipCode << "\",";
            cout << "\"county\":\"" << n.county << "\",";
            cout << "\"market_tier\":\"" << n.marketTier << "\",";
            cout << "\"region_bucket\":\"" << n.regionBucket << "\",";
            cout << "\"urban_core_flag\":" << n.urbanCoreFlag << ",";
            cout << "\"similarity_score\":" << simPct << ",";
            cout << "\"property_value\":" << n.propertyValue;
            cout << "}";
            if (i + 1 < topNeighbors.size()) cout << ",";
        }
        cout << "]";
        cout << "}\n";

        return 0;
    } catch (const exception& e) {
        cerr << "{\"error\":\"" << e.what() << "\"}\n";
        return 1;
    }
}