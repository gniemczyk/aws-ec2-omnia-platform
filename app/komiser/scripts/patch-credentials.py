with open('/src/handlers/helper.go', 'r') as f:
    content = f.read()

content = content.replace(
    'awsConfig "github.com/aws/aws-sdk-go-v2/config"',
    'awsConfig "github.com/aws/aws-sdk-go-v2/config"\n\t"github.com/aws/aws-sdk-go-v2/credentials"'
)

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

content = content.replace(old_block, new_block)

with open('/src/handlers/helper.go', 'w') as f:
    f.write(content)
print('Patch applied successfully')
