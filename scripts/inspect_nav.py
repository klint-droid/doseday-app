import json

with open('assets/figma_ref/node_1_87.json', 'r', encoding='utf-8') as f:
    d = json.load(f)

def find_node(node, node_id):
    if node.get('id') == node_id:
        return node
    for child in node.get('children', []):
        res = find_node(child, node_id)
        if res:
            return res
    return None

for nid in ['101:221', '101:250', '101:258', '101:216']:
    n = find_node(d['nodes']['1:87']['document'], nid)
    print(f"\nNode {nid} ({n.get('name')}):")
    for fg in n.get('fillGeometry', []):
        print("  fill path:", fg.get('path')[:100] + "...")
