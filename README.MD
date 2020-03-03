# SolarEdge Collection Project

![image](/images/SolarEdgeProject.png)

## Infrastructure
This project uses 2 LogicApps and 2 Azure Functions.

### LogicApps
DailySunrRiseSetTime - Collects Sunrise and Sunset times for your GPS location. 
SolarCollectionAlert - Fired by Azure Monitor Log Search Alert to turn off SolarDailyMonitor Azure Function

### Azure Functions
SolarDailyMonitor - Runs every 15 minutes during the day to collect 'live' production data. Runs after being turned on and off by SolarCollectionAlert
SolarDailyCollection - Runs every night at 10pm local time to collect the days total production

### Log Analytics Workspace
Used as data collection repository with maximum 2 year retention. Sending data via the Public API.


### Blog Posts
Azure Functions Setup https://www.systemcenterautomation.com/2020/03/collect-solaredge-data-azure-functions/  

Grab Sunrise time from your GPS Location. https://www.systemcenterautomation.com/2019/05/custom-log-analytics-logs-logicappsps/

Use LogicApp to turn off and on Azure Function from Azure Monitor Alert. https://www.systemcenterautomation.com/2020/02/azure-monitor-alert-logicapp/

Set Managed Identity for LogicApp on Azure Functions. https://www.systemcenterautomation.com/2019/04/managed-identity-logic-app/
