import json

with open('/src/handlers/accounts_handler.go', 'r') as f:
    content = f.read()

old_rescan = '''func (handler *ApiHandler) ReScanAccount(c *gin.Context) {
\taccountId := c.Param("id")

\taccount := new(models.Account)
\taccount.Status = "SCANNING"
\trows, err := handler.ctrl.RescanAccount(c, account, accountId)
\tif err != nil {
\t\tlog.Error("Couldn't set status", err)
\t\treturn
\t}
\tif rows > 0 {
\t\tgo fetchResourcesForAccount(handler.ctx, *account, handler.db, []string{})
\t}

\tc.JSON(http.StatusOK, "Rescan Triggered")
}'''

new_rescan = '''func (handler *ApiHandler) ReScanAccount(c *gin.Context) {
\taccountId := c.Param("id")

\taccounts, err := handler.ctrl.ListAccounts(c)
\tif err != nil {
\t\tc.JSON(http.StatusInternalServerError, gin.H{"error": "scan failed"})
\t\treturn
\t}

\tvar target *models.Account
\tfor _, a := range accounts {
\t\tif strconv.FormatInt(a.Id, 10) == accountId {
\t\t\ttarget = &a
\t\t\tbreak
\t\t}
\t}
\tif target == nil {
\t\tc.JSON(http.StatusNotFound, gin.H{"error": "account not found"})
\t\treturn
\t}

\ttarget.Status = "SCANNING"
\trows, err := handler.ctrl.RescanAccount(c, target, accountId)
\tif err != nil {
\t\tlog.Error("Couldn't set status", err)
\t\treturn
\t}
\tif rows > 0 {
\t\tgo fetchResourcesForAccount(handler.ctx, *target, handler.db, []string{})
\t}

\tc.JSON(http.StatusOK, "Rescan Triggered")
}'''

if old_rescan not in content:
    print('ERROR: Could not find ReScanAccount in source')
    exit(1)
content = content.replace(old_rescan, new_rescan)
if new_rescan not in content:
    print('ERROR: Failed to replace ReScanAccount')
    exit(1)
print('ReScanAccount patched')

old_update = '''func (handler *ApiHandler) UpdateCloudAccountHandler(c *gin.Context) {
\taccountId := c.Param("id")

\tvar account models.Account
\terr := json.NewDecoder(c.Request.Body).Decode(&account)
\tif err != nil {
\t\tc.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
\t\treturn
\t}

\terr = handler.ctrl.UpdateAccount(c, account, accountId)
\tif err != nil {
\t\tc.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
\t\treturn
\t}

\tc.JSON(http.StatusOK, account)
}'''

new_update = '''func (handler *ApiHandler) UpdateCloudAccountHandler(c *gin.Context) {
\taccountId := c.Param("id")

\tvar account models.Account
\terr := json.NewDecoder(c.Request.Body).Decode(&account)
\tif err != nil {
\t\tc.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
\t\treturn
\t}

\terr = handler.ctrl.UpdateAccount(c, account, accountId)
\tif err != nil {
\t\tc.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
\t\treturn
\t}

\tgo fetchResourcesForAccount(handler.ctx, account, handler.db, []string{})

\tc.JSON(http.StatusOK, account)
}'''

if old_update not in content:
    print('ERROR: Could not find UpdateCloudAccountHandler in source')
    exit(1)
content = content.replace(old_update, new_update)
if new_update not in content:
    print('ERROR: Failed to replace UpdateCloudAccountHandler')
    exit(1)
print('UpdateCloudAccountHandler patched')

# Add strconv import if not present
if 'strconv' not in content:
    content = content.replace(
        '"github.com/gin-gonic/gin"',
        '"github.com/gin-gonic/gin"\n\t"strconv"'
    )

with open('/src/handlers/accounts_handler.go', 'w') as f:
    f.write(content)
print('Accounts handler patched successfully')
