with open('governance.tf', 'r') as f:
    content = f.read()

target = '''          name = "check-resource-limits"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }'''

replacement = '''          name = "check-resource-limits"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          exclude = {
            any = [
              { resources = { namespaces = ["kube-system", "linkerd", "cert-manager", "vpa"] } }
            ]
          }'''

if target in content:
    with open('governance.tf', 'w') as f:
        f.write(content.replace(target, replacement))
    print("Patched successfully")
else:
    print("Target not found")
