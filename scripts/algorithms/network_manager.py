import networkx as nx
import numpy as np
import os


class NetworkManager:
    def __init__(self, weights=(0.33, 0.33, 0.34)):
        # Robust path handling: Get the directory of the current script
        base_dir = os.path.dirname(os.path.abspath(__file__))

        # Point to the sibling 'data' folder
        self.data_folder = os.path.abspath(os.path.join(base_dir, '../data'))

        # Initialize Graph
        self.G = nx.Graph()
        self.demands = []

        # Optimization weights
        self.weights = weights

        # Execute loaders
        self.load_nodes()
        self.load_edges()
        self.load_demands()

    def load_nodes(self):
        # Simplified path joining using the absolute data_folder path
        file_path = os.path.join(self.data_folder, 'nodes.csv')

        if not os.path.exists(file_path):
            print(f"Error: {file_path} not found.")
            return

        with open(file_path, 'r', encoding='utf-8') as file:
            next(file)  # Skip header

            for line in file:
                parts = line.strip().split(';')
                if len(parts) < 3: continue

                node_id = int(parts[0])
                # Handle comma/dot decimal separator
                proc_delay = float(parts[1].replace(',', '.'))
                reliability = float(parts[2].replace(',', '.'))

                self.G.add_node(node_id,
                                processing_delay=proc_delay,
                                reliability=reliability)

    def load_edges(self):
        # Updated filename to edges.csv
        file_path = os.path.join(self.data_folder, 'edges.csv')

        if not os.path.exists(file_path):
            print(f"Error: {file_path} not found.")
            return

        with open(file_path, 'r', encoding='utf-8') as file:
            next(file)  # Skip header

            for line in file:
                parts = line.strip().split(';')
                if len(parts) < 5: continue

                source_node = int(parts[0])
                destination_node = int(parts[1])
                bw = int(parts[2])
                delay = int(parts[3])
                rel = float(parts[4].replace(',', '.'))

                self.G.add_edge(source_node, destination_node,
                                bandwidth=bw,
                                link_delay=delay,
                                reliability=rel)

    def load_demands(self):
        # Updated filename to demand.csv
        file_path = os.path.join(self.data_folder, 'demand.csv')

        if not os.path.exists(file_path):
            print(f"Error: {file_path} not found.")
            return

        with open(file_path, 'r', encoding='utf-8') as file:
            next(file)  # Skip header
            for line in file:
                parts = line.strip().split(';')
                if len(parts) < 3: continue

                self.demands.append({
                    'src': int(parts[0]),
                    'dst': int(parts[1]),
                    'bw_demand': int(parts[2])
                })

    def calculate_fitness(self, path, weights=(0.33, 0.33, 0.34)):
        if not path or len(path) < 2:
            return {
                "fitness": float('inf'),
                "total_delay": float('inf'),
                "total_reliability": 0.0,
                "resource_cost": float('inf')
            }

        w_delay, w_rel, w_res = weights

        total_delay = 0
        total_rel_cost = 0
        total_res_cost = 0

        # 1. Node Calculations
        for node_id in path[1:-1]:
            node_data = self.G.nodes[node_id]
            total_delay += node_data.get('processing_delay', 0)

            rel = node_data.get('reliability', 0.99)
            total_rel_cost += -np.log(rel) if rel > 0 else 100

        # 2. Edge Calculations
        for i in range(len(path) - 1):
            source_node = path[i]
            destination_node = path[i + 1]

            if not self.G.has_edge(source_node, destination_node):
                return {
                    "fitness": float('inf'),
                    "total_delay": float('inf'),
                    "total_reliability": 0.0,
                    "resource_cost": float('inf')
                }

            edge_data = self.G[source_node][destination_node]

            total_delay += edge_data.get('link_delay', 0)

            link_rel = edge_data.get('reliability', 0.99)
            total_rel_cost += -np.log(link_rel) if link_rel > 0 else 100

            bw = edge_data.get('bandwidth', 1)
            total_res_cost += (1000.0 / bw) if bw > 0 else 100

        fitness = (w_delay * total_delay) + \
                  (w_rel * total_rel_cost) + \
                  (w_res * total_res_cost)

        return {
            "fitness": fitness,
            "total_delay": total_delay,
            "total_reliability": np.exp(-total_rel_cost),
            "resource_cost": total_res_cost
        }

    def calculate_metrics(self, path):
        """Uses internal weights for metric calculation."""
        # Reuse the logic from calculate_fitness but use self.weights
        return self.calculate_fitness(path, self.weights)

    def find_initial_paths(self, start, end, limit=5):
        paths = []
        try:
            raw_paths_generator = nx.shortest_simple_paths(self.G, start, end)
            for p in raw_paths_generator:
                paths.append(p)
                if len(paths) >= limit:
                    break
        except nx.NetworkXNoPath:
            return []

        return paths