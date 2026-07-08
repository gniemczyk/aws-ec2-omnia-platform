with open('/src/handlers/helper.go', 'r') as f:
    content = f.read()

if 'awsConfig "github.com/aws/aws-sdk-go-v2/config"' not in content:
    print('ERROR: Could not find awsConfig import')
    exit(1)

content = content.replace(
    'awsConfig "github.com/aws/aws-sdk-go-v2/config"',
    'awsConfig "github.com/aws/aws-sdk-go-v2/config"\n\t"github.com/aws/aws-sdk-go-v2/credentials"'
)

if 'credentials"' not in content:
    print('ERROR: Failed to add credentials import')
    exit(1)
print('Import added')

old_block = '''\t\t} else {
\t\t\tcfg, err := awsConfig.LoadDefaultConfig(context.Background())
\t\t\tif err != nil {
\t\t\t\treturn nil, err
\t\t\t}
\t\t\treturn &providers.ProviderClient{
\t\t\t\tAWSClient: &cfg,
\t\t\t\tName:      account.Name,
\t\t\t}, nil
\t\t}'''

new_block = '''\t\t} else if account.Credentials["source"] == "credentials-keys" {
\t\t\tcfg, err := awsConfig.LoadDefaultConfig(
\t\t\t\tcontext.Background(),
\t\t\t\tawsConfig.WithRegion(account.Credentials["region"]),
\t\t\t\tawsConfig.WithCredentialsProvider(
\t\t\t\t\tcredentials.NewStaticCredentialsProvider(
\t\t\t\t\t\taccount.Credentials["aws_access_key_id"],
\t\t\t\t\t\taccount.Credentials["aws_secret_access_key"],
\t\t\t\t\t\t"",
\t\t\t\t\t),
\t\t\t\t),
\t\t\t)
\t\t\tif err != nil {
\t\t\t\treturn nil, err
\t\t\t}
\t\t\treturn &providers.ProviderClient{
\t\t\t\tAWSClient: &cfg,
\t\t\t\tName:      account.Name,
\t\t\t}, nil
\t\t} else {
\t\t\tcfg, err := awsConfig.LoadDefaultConfig(context.Background())
\t\t\tif err != nil {
\t\t\t\treturn nil, err
\t\t\t}
\t\t\treturn &providers.ProviderClient{
\t\t\t\tAWSClient: &cfg,
\t\t\t\tName:      account.Name,
\t\t\t}, nil
\t\t}'''

if old_block not in content:
    print('ERROR: Could not find the else block to patch')
    print('--- repr of first 100 chars ---')
    print(repr(old_block[:100]))
    exit(1)

content = content.replace(old_block, new_block)

if new_block not in content:
    print('ERROR: Failed to replace else block')
    exit(1)
print('Else block patched')

# Also fix provider case for all checks
content = content.replace(
    'if account.Provider == "aws"',
    'if account.Provider == "aws" || account.Provider == "AWS"'
)
content = content.replace(
    'if account.Provider == "digitalocean"',
    'if account.Provider == "digitalocean" || account.Provider == "DigitalOcean"'
)
content = content.replace(
    'if account.Provider == "oci"',
    'if account.Provider == "oci" || account.Provider == "OCI"'
)
content = content.replace(
    'if account.Provider == "civo"',
    'if account.Provider == "civo" || account.Provider == "Civo"'
)
content = content.replace(
    'if account.Provider == "kubernetes"',
    'if account.Provider == "kubernetes" || account.Provider == "Kubernetes"'
)
content = content.replace(
    'if account.Provider == "linode"',
    'if account.Provider == "linode" || account.Provider == "Linode"'
)
content = content.replace(
    'if account.Provider == "tencent"',
    'if account.Provider == "tencent" || account.Provider == "Tencent"'
)
content = content.replace(
    'if account.Provider == "azure"',
    'if account.Provider == "azure" || account.Provider == "Azure"'
)
content = content.replace(
    'if account.Provider == "scaleway"',
    'if account.Provider == "scaleway" || account.Provider == "Scaleway"'
)
content = content.replace(
    'if account.Provider == "mongodb"',
    'if account.Provider == "mongodb" || account.Provider == "MongoDB"'
)
content = content.replace(
    'if account.Provider == "gcp"',
    'if account.Provider == "gcp" || account.Provider == "GCP"'
)
content = content.replace(
    'if account.Provider == "ovh"',
    'if account.Provider == "ovh" || account.Provider == "OVH"'
)
print('Provider case checks patched')

with open('/src/handlers/helper.go', 'w') as f:
    f.write(content)
print('Patch applied successfully')
