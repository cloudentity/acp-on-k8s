import json, sys, yaml

def repr_str(dumper, data):
    if '\n' in data:
        return dumper.represent_scalar(u'tag:yaml.org,2002:str', data, style='|')
    return dumper.represent_str(data)

yaml.add_representer(str, repr_str, Dumper=yaml.SafeDumper)

y=yaml.safe_load(sys.stdin.read())

y['data']['mesh'] += """
extensionProviders:
- name: "acp-authorizer"
  envoyExtAuthzGrpc:
    service: "istio-authorizer.acp-system.svc.cluster.local"
    port: "9001"\n"""

yaml.safe_dump(y, sys.stdout)