import networkx as nx
import random
import json

class NetworkGenerator:
    def __init__(self, num_nodes=250, connection_probability=0.4):
        self.num_nodes = num_nodes
        self.connection_probability = connection_probability
        self.graph = None
    
    def generate_network(self):
        self.graph = nx.erdos_renyi_graph(n=self.num_nodes, p=self.connection_probability)
        
        while not nx.is_connected(self.graph):
            self.graph = nx.erdos_renyi_graph(n=self.num_nodes, p=self.connection_probability + 0.05)
        
        self._assign_node_properties()
        self._assign_link_properties()
        return self.graph
    
    def _assign_node_properties(self):
        for node in self.graph.nodes():
            self.graph.nodes[node]['processing_delay'] = random.uniform(0.5, 2.0)
            self.graph.nodes[node]['reliability'] = random.uniform(0.95, 0.999)
    
    def _assign_link_properties(self):
        for edge in self.graph.edges():
            self.graph.edges[edge]['bandwidth'] = random.randint(100, 1000)
            self.graph.edges[edge]['delay'] = random.uniform(3.0, 15.0)
            self.graph.edges[edge]['reliability'] = random.uniform(0.95, 0.999)
    
    def save_network(self, filename):
        network_data = {'nodes': {}, 'edges': []}
        
        for node in self.graph.nodes():
            network_data['nodes'][str(node)] = {
                'processing_delay': self.graph.nodes[node]['processing_delay'],
                'reliability': self.graph.nodes[node]['reliability']
            }
        
        for edge in self.graph.edges():
            network_data['edges'].append({
                'source': edge[0], 'target': edge[1],
                'bandwidth': self.graph.edges[edge]['bandwidth'],
                'delay': self.graph.edges[edge]['delay'],
                'reliability': self.graph.edges[edge]['reliability']
            })
        
        with open(filename, 'w') as f:
            json.dump(network_data, f, indent=2)









# Ağ üretme deneme kodu:
if __name__ == "__main__":
    generator = NetworkGenerator(num_nodes=250, connection_probability=0.4)
    network = generator.generate_network()
    print(f"✅ Bağlı ağ oluşturuldu!")
    print(f"   Düğüm sayısı: {network.number_of_nodes()}")
    print(f"   Bağlantı sayısı: {network.number_of_edges()}")
    
    # İlk düğüm ve bağlantıyı göster
    first_node = list(network.nodes())[0]
    print(f"\n📊 Örnek düğüm ({first_node}):")
    print(f"   İşlem gecikmesi: {network.nodes[first_node]['processing_delay']:.3f} ms")
    print(f"   Güvenilirlik: {network.nodes[first_node]['reliability']:.3f}")
    
    # Kaydet
    generator.save_network("test_network.json")
    print(f"\n💾 Ağ 'test_network.json' dosyasına kaydedildi")