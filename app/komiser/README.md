# Komiser - Cloud Environment Inspector

Komiser to narzędzie do monitorowania i wizualizacji zasobów AWS.

## Uruchomienie

```bash
cd app/komiser/
docker compose up -d --build
```

Aplikacja dostępna pod adresem: `http://localhost:3001`

## Konfiguracja połączenia z AWS

### Opcja 1 (rekomendowana) - przez zmienne środowiskowe

Przed uruchomieniem utwórz plik `.env` na podstawie `.env.example` i wpisz klucze IAM:

```bash
cp .env.example .env
# edytuj .env - wpisz AWS_ACCESS_KEY_ID i AWS_SECRET_ACCESS_KEY
```

Następnie uruchom kontener:

```bash
docker compose up -d --build
```

### Opcja 2 - przez UI Cloud Accounts

Jeśli kontener jest już uruchomiony, możesz dodać konto ręcznie:

1. Wejdź w **Cloud Accounts** (lub `/cloud-accounts`)
2. Kliknij **Connect Account** → **AWS**
3. Wpisz nazwę, `Access Key ID` i `Secret Access Key`
4. Po zapisaniu Komiser rozpocznie skanowanie

> ⚠️ **Uwaga:** Klucze IAM muszą mieć przypisaną politykę **ReadOnlyAccess** (`arn:aws:iam::aws:policy/ReadOnlyAccess`).

## Troubleshooting

| Objaw | Przyczyna | Rozwiązanie |
|-------|-----------|-------------|
| `no EC2 IMDS role found` | Brak kredencjałów AWS | Dodaj Cloud Account ręcznie (instrukcja wyżej) |
| `incorrect costexplorerOutputList` | Brak dostępu do Cost Explorer | Dodaj `aws:ce:*` do polityki IAM |
| `Failed to list IAM users` | Zbyt ograniczona polityka | Użyj `ReadOnlyAccess` zamiast customowej |
