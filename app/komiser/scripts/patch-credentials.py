with open('/src/handlers/helper.go', 'r') as f:
    content = f.read()

content = content.replace(
    'awsConfig "github.com/aws/aws-sdk-go-v2/config"',
    'awsConfig "github.com/aws/aws-sdk-go-v2/config"\n\t"github.com/aws/aws-sdk-go-v2/credentials"'
)

old = '\t\t\tcfg, err := awsConfig.LoadDefaultConfig(context.Background())'
new = '''\t\t\tcfg, err := awsConfig.LoadDefaultConfig(
\t\t\t\tcontext.Background(),
\t\t\t\tawsConfig.WithCredentialsProvider(
\t\t\t\t\tcredentials.NewStaticCredentialsProvider(
\t\t\t\t\t\taccount.Credentials["aws_access_key_id"],
\t\t\t\t\t\taccount.Credentials["aws_secret_access_key"],
\t\t\t\t\t\t"",
\t\t\t\t\t),
\t\t\t\t),
\t\t\t)'''
content = content.replace(old, new)

with open('/src/handlers/helper.go', 'w') as f:
    f.write(content)
print('Patch applied successfully')
