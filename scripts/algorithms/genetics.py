import random
import time
import os
import sys
import csv
import networkx as nx


current_dir = os.path.dirname(os.path.abspath(__file__))
src_dir = os.path.abspath(os.path.join(current_dir, ".."))
if src_dir not in sys.path:
    sys.path.append(src_dir)

from network_manager import NetworkManager



def csvden_parametreleri_oku(dosya_adi="genetic_input.csv"):
    parametreler = {}
    with open(dosya_adi, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for satir in reader:
            parametreler[satir["parametre"]] = satir["deger"]
    return parametreler


class GenetikAlgoritma:
    def __init__(self, network, agirliklar,
                 pop_size=100, nesil_sayisi=200, mutasyon_orani=0.05):
        self.network = network
        self.G = network.G
        self.agirliklar = agirliklar
        self.pop_size = pop_size
        self.nesil_sayisi = nesil_sayisi
        self.mutasyon_orani = mutasyon_orani

    def rastgele_yol(self, kaynak, hedef, max_adim=300):
        yol = [kaynak]
        mevcut = kaynak
        for _ in range(max_adim):
            komsular = list(self.G.neighbors(mevcut))
            if not komsular:
                return None
            secilen = random.choice(komsular)
            if secilen not in yol:
                yol.append(secilen)
                if secilen == hedef:
                    return yol
                mevcut = secilen
        return None

    def baslangic_populasyonu(self, kaynak, hedef):
        pop = []
        while len(pop) < self.pop_size:
            p = self.rastgele_yol(kaynak, hedef)
            if p:
                pop.append(p)
        return pop

    def turnuva_secimi(self, populasyon, k=3):
        adaylar = random.sample(populasyon, k)
        adaylar.sort(
            key=lambda p: self.network.calculate_fitness(p, self.agirliklar)["fitness"]
        )
        return adaylar[0]

    def caprazlama(self, p1, p2):
        ortaklar = list(set(p1[1:-1]) & set(p2[1:-1]))
        if not ortaklar:
            return p1[:]
        c = random.choice(ortaklar)
        return p1[:p1.index(c)] + p2[p2.index(c):]

    def mutasyon(self, yol, hedef):
        if random.random() > self.mutasyon_orani or len(yol) < 3:
            return yol
        idx = random.randint(1, len(yol) - 2)
        try:
            kuyruk = nx.shortest_path(self.G, yol[idx], hedef)
            return yol[:idx] + kuyruk
        except:
            return yol

    def calistir(self, kaynak, hedef):
        populasyon = self.baslangic_populasyonu(kaynak, hedef)
        en_iyi_yol = None
        en_iyi_fitness = float("inf")

        for _ in range(self.nesil_sayisi):
            degerlendirilmis = []
            for yol in populasyon:
                f = self.network.calculate_fitness(yol, self.agirliklar)["fitness"]
                if f != float("inf"):
                    degerlendirilmis.append((yol, f))

            if not degerlendirilmis:
                continue

            degerlendirilmis.sort(key=lambda x: x[1])

            if degerlendirilmis[0][1] < en_iyi_fitness:
                en_iyi_yol, en_iyi_fitness = degerlendirilmis[0]

            yeni_pop = [degerlendirilmis[0][0]]  # elitizm

            while len(yeni_pop) < self.pop_size:
                ebeveyn1 = self.turnuva_secimi([p for p, _ in degerlendirilmis])
                ebeveyn2 = self.turnuva_secimi([p for p, _ in degerlendirilmis])
                cocuk = self.mutasyon(self.caprazlama(ebeveyn1, ebeveyn2), hedef)
                yeni_pop.append(cocuk)

            populasyon = yeni_pop

        return en_iyi_yol, en_iyi_fitness

def save_minimal_path(yol, filename=r"../data/genetic_path.csv"):
    """
    Exports the found path to a clean, precise, and minimalist CSV file.
    Format: order, node_id
    """
    if not yol:
        return

    # Resolve absolute path relative to script location
    current_dir = os.path.dirname(os.path.abspath(__file__))
    abs_path = os.path.abspath(os.path.join(current_dir, filename))

    try:
        with open(abs_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            # Minimalist Header
            writer.writerow(["order", "node_id"])
            # Write path sequence
            for i, node in enumerate(yol):
                writer.writerow([i, node])
        print(f"Minimal path exported to: {abs_path}")
    except Exception as e:
        print(f"Error exporting minimal path CSV: {e}")

if __name__ == "__main__":

    # 🔹 CSV’den input oku
    p = csvden_parametreleri_oku("../data/genetic_input.csv")

    KAYNAK = int(p["kaynak"])
    HEDEF = int(p["hedef"])
    

    agirliklar = (
        float(p["agirlik_delay"]),
        float(p["agirlik_reliability"]),
        float(p["agirlik_cost"])
    )

    network = NetworkManager()
    ga = GenetikAlgoritma(network, agirliklar, 100, 200, 0.05)

    baslangic = time.time()
    yol, fitness = ga.calistir(KAYNAK, HEDEF)
    sure = time.time() - baslangic

    if yol:
        save_minimal_path(yol)

    metrikler = network.calculate_fitness(yol, agirliklar)
    print("\n")
    print("Genetik Algoritma Sonuclari:")
    print("En İyi Yol:", " → ".join(map(str, yol)))
    print("Toplam Gecikme (ms):", round(metrikler["total_delay"], 4))
    print("Guvenilirlik (%):", round(metrikler["total_reliability"] * 100, 2))
    print("Kaynak Maliyeti:", round(metrikler["resource_cost"], 6))
    print("Fitness:", round(metrikler["fitness"], 6))
    print("Sure (sn):", round(sure, 4))
    
    with open("../data/genetics_output.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Alan", "Deger"])
        writer.writerow(["Kaynak", KAYNAK])
        writer.writerow(["Hedef", HEDEF])
        writer.writerow(["Yol", " → ".join(map(str, yol))])
        writer.writerow(["Toplam Gecikme (ms)", round(metrikler["total_delay"], 4)])
        writer.writerow(["Guvenilirlik (%)", round(metrikler["total_reliability"] * 100, 2)])
        writer.writerow(["Kaynak Maliyeti", round(metrikler["resource_cost"], 6)])
        writer.writerow(["Fitness", round(metrikler["fitness"], 6)])
        writer.writerow(["Sure (sn)", round(sure, 4)])


