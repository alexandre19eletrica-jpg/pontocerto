# Exportacoes De Observabilidade

Esta pasta guarda snapshots locais da observabilidade da empresa suprema para analise externa.

Formato:

- um diretório por data
- um arquivo `json` com o payload completo
- um arquivo `md` com leitura resumida e copiavel

Script:

- [export_observability_snapshot.ps1](C:/Users/hp/pontocerto/scripts/export_observability_snapshot.ps1)

Uso:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export_observability_snapshot.ps1
```
