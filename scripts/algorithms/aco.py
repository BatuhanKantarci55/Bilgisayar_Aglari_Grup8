import networkx as nx
import random
import numpy as np
import math
import os
import sys
import csv
import time

# Import NetworkManager directly since it is in the same folder
try:
    from network_manager import NetworkManager
except ImportError:
    print("Error: network_manager.py must be in the same folder as this script.")
    sys.exit(1)


def csvden_parametreleri_oku(dosya_adi=r"../data/aco_input.csv"):
    """
    Reads parameters from CSV. If file is missing, returns fallback defaults.
    """
    # Get the absolute path relative to this script
    current_dir = os.path.dirname(os.path.abspath(__file__))
    abs_path = os.path.abspath(os.path.join(current_dir, dosya_adi))

    if not os.path.exists(abs_path):
        print(f"Warning: {dosya_adi} not found. Using fallback defaults.")
        # Default internal values for standalone execution
        return {
            "kaynak": "0",
            "hedef": "249",
            "karinca_sayisi": "30",
            "iterasyon": "50",
            "alfa": "1.0",
            "beta": "2.0",
            "buharlasma": "0.1",
            "q_degeri": "100.0",
            "agirlik_delay": "0.33",
            "agirlik_reliability": "0.33",
            "agirlik_cost": "0.34"
        }

    parametreler = {}
    with open(abs_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for satir in reader:
            if "parametre" in satir and "deger" in satir:
                parametreler[satir["parametre"]] = satir["deger"]
    return parametreler


def export_path_csv(yol, dosya_adi=r"../data/aco_path.csv"):
    """
    Exports the found path to a clean, minimalist CSV file.
    Format: step, node_id
    """
    current_dir = os.path.dirname(os.path.abspath(__file__))
    abs_path = os.path.abspath(os.path.join(current_dir, dosya_adi))

    try:
        with open(abs_path, mode="w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["step", "node_id"])
            for step, node in enumerate(yol):
                writer.writerow([step, node])
    except Exception as e:
        print(f"Warning: Failed to export path csv: {e}")


class KarincaKolonisiOptimizasyonu:
    def __init__(self, network, agirliklar, karinca_sayisi=30, iterasyon_sayisi=50,
                 alfa=1.0, beta=2.0, buharlasma_orani=0.1, q_degeri=100.0):
        self.manager = network
        self.grafik = network.G
        self.agirliklar = agirliklar
        self.karinca_sayisi = karinca_sayisi
        self.iterasyon_sayisi = iterasyon_sayisi
        self.alfa = alfa
        self.beta = beta
        self.buharlasma_orani = buharlasma_orani
        self.q_degeri = q_degeri
        self.feromonlari_baslat()

    def feromonlari_baslat(self):
        """Initial pheromone setup on edges."""
        for u, v in self.grafik.edges():
            if 'feromon' not in self.grafik[u][v]:
                self.grafik[u][v]['feromon'] = 1.0

    def sezgisel_hesapla(self, u, v):
        """Calculates edge desirability based on delay, reliability, and cost."""
        w_d, w_r, w_res = self.agirliklar
        edge = self.grafik[u][v]
        node = self.grafik.nodes[v]

        local_delay = edge.get('link_delay', 10.0) + node.get('processing_delay', 1.0)

        rel_score = edge.get('reliability', 0.99) * node.get('reliability', 0.99)
        local_rel_cost = -math.log(rel_score) if rel_score > 0 else 100

        bw = edge.get('bandwidth', 100)
        local_res_cost = 1000.0 / bw if bw > 0 else 100

        total_local_cost = (w_d * local_delay) + (w_r * local_rel_cost) + (w_res * local_res_cost)
        return 1.0 / total_local_cost if total_local_cost > 0 else 0.0001

    def cozum_olustur(self, kaynak, hedef):
        """Constructs a single ant's path through the network."""
        mevcut = kaynak
        yol = [mevcut]
        ziyaret_edilenler = {mevcut}
        max_adim = len(self.grafik.nodes) * 2

        for _ in range(max_adim):
            if mevcut == hedef: return yol

            komsular = [n for n in self.grafik.neighbors(mevcut) if n not in ziyaret_edilenler]
            if not komsular: return None

            olasiliklar = []
            for komsu in komsular:
                tau = self.grafik[mevcut][komsu].get('feromon', 1.0)
                eta = self.sezgisel_hesapla(mevcut, komsu)
                olasiliklar.append(math.pow(tau, self.alfa) * math.pow(eta, self.beta))

            payda = sum(olasiliklar)
            if payda == 0:
                secilen = random.choice(komsular)
            else:
                olasiliklar = [p / payda for p in olasiliklar]
                secilen = np.random.choice(komsular, p=olasiliklar)

            yol.append(secilen)
            ziyaret_edilenler.add(secilen)
            mevcut = secilen
        return None

    def feromon_guncelle(self, yollar_ve_maliyetler):
        """Applies evaporation and updates pheromones for successful paths."""
        for u, v in self.grafik.edges():
            self.grafik[u][v]['feromon'] *= (1.0 - self.buharlasma_orani)
            if self.grafik[u][v]['feromon'] < 0.01: self.grafik[u][v]['feromon'] = 0.01

        for yol, maliyet in yollar_ve_maliyetler:
            if maliyet > 0 and maliyet != float('inf'):
                birakilacak_miktar = self.q_degeri / maliyet
                for i in range(len(yol) - 1):
                    u, v = yol[i], yol[i + 1]
                    self.grafik[u][v]['feromon'] += birakilacak_miktar

    def calistir(self, kaynak, hedef):
        """Main iterative loop for the ACO algorithm."""
        en_iyi_yol, en_iyi_fitness = None, float('inf')

        for _ in range(self.iterasyon_sayisi):
            bu_iter_yollar = []
            for _ in range(self.karinca_sayisi):
                yol = self.cozum_olustur(kaynak, hedef)
                if yol:
                    res = self.manager.calculate_fitness(yol, self.agirliklar)
                    maliyet = res["fitness"] if isinstance(res, dict) else res
                    if maliyet < en_iyi_fitness:
                        en_iyi_fitness, en_iyi_yol = maliyet, yol
                    bu_iter_yollar.append((yol, maliyet))
            self.feromon_guncelle(bu_iter_yollar)
        return en_iyi_yol, en_iyi_fitness


def run_aco():
    """
    Default method: Reads input, executes optimization, and writes results to ../data/.
    """
    # Relative path settings
    input_rel = r"../data/aco_input.csv"
    output_rel = r"../data/aco_output.csv"

    params = csvden_parametreleri_oku(input_rel)

    try:
        KAYNAK = int(params["kaynak"])
        HEDEF = int(params["hedef"])
        agirliklar = (float(params["agirlik_delay"]), float(params["agirlik_reliability"]),
                      float(params["agirlik_cost"]))

        # NetworkManager initialization
        network = NetworkManager()

        aco = KarincaKolonisiOptimizasyonu(
            network, agirliklar,
            int(params["karinca_sayisi"]), int(params["iterasyon"]),
            float(params["alfa"]), float(params["beta"]), float(params["buharlasma"]), float(params["q_degeri"])
        )

        start_time = time.time()
        yol, fitness = aco.calistir(KAYNAK, HEDEF)
        sure = time.time() - start_time

        metrikler = network.calculate_fitness(yol, agirliklar) if yol else \
            {"fitness": float('inf'), "total_delay": 0, "total_reliability": 0, "resource_cost": 0}

        # Save results to output file
        current_dir = os.path.dirname(os.path.abspath(__file__))
        out_path = os.path.abspath(os.path.join(current_dir, output_rel))

        with open(out_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["Alan", "Deger"])
            writer.writerow(["Kaynak", KAYNAK])
            writer.writerow(["Hedef", HEDEF])
            writer.writerow(["Yol", " → ".join(map(str, yol)) if yol else "BULUNAMADI"])
            writer.writerow(["Fitness", round(metrikler["fitness"], 6)])
            writer.writerow(["Gecikme (ms)", round(metrikler.get("total_delay", 0), 4)])
            writer.writerow(["Guvenilirlik (%)", round(metrikler.get("total_reliability", 0) * 100, 2)])
            writer.writerow(["Sure (sn)", round(sure, 4)])

        # Automatically export the minimalist path CSV if a path was found
        if yol:
            export_path_csv(yol)

        return {"yol": yol, "fitness": fitness, "sure": sure}
    except Exception as e:
        print(f"Critical Error: {e}")
        return None


if __name__ == "__main__":
    print("Initializing Ant Colony Optimization...")
    res = run_aco()
    if res and res["yol"]:
        print(f"Success. Best Fitness: {res['fitness']:.4f}")
    else:
        print("Search completed without finding a valid path.")