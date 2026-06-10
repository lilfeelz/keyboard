import sys, yaml

reorder = [
    0,1,2,3,4,5,6,7,8,9,
    20,10,11,12,13,14,15,16,17,18,19,31,
    21,22,23,24,25,26,27,28,29,30,
    32,33,34,35,36,37
]

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)

for name, bindings in data.get('layers', {}).items():
    if isinstance(bindings, list) and len(bindings) == 38:
        data['layers'][name] = [bindings[i] for i in reorder]

with open(sys.argv[2], 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
