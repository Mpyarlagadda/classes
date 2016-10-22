/**
* @author Yamuna
* @date 20 October 2016
*
* @description This class is used to manage business logic for Estimate_Header Run
*/
public class RSP_Estimate_Helper
{
    private static final String STATUS_READY_TO_PROCESS = 'Ready to Process';
    private static final String STATUS_WAITING = 'Waiting';
    private static final String STATUS_SETTLEMENT_RUN_COMPLETE = 'Settlement Run Complete';
    
    public static void createEstimateHeaderLineItems(List<Estimate_Header__c> oldEstimateHeader,List<Estimate_Header__c> newEstimateHeader)
    {
        List<Estimate_Line_Item__c> lstEstimateLineItem=new List<Estimate_Line_Item__c>();
        List<Account> lstaccount=[Select Id from Account where Estimate__c = true and Type != 'Agent'];

        if(newEstimateHeader != null && !newEstimateHeader.isEmpty() && newEstimateHeader.size() == 1 &&
        newEstimateHeader[0].Status__c == STATUS_READY_TO_PROCESS && newEstimateHeader[0].Year__c != null && newEstimateHeader[0].Period_Set__c != null)
        { 
            List<Account> accountList=RSP_Estimate_Service.listAccounts(newEstimateHeader[0]);
            System.debug(accountList);
            lstEstimateLineItem =createEstimateLines(newEstimateHeader[0].Id,accountList);
            RSP_Estimate_Service.insertEstimateLineItem(lstEstimateLineItem);
        }
    }
    
    private static List<Estimate_Line_Item__c> createEstimateLines(Id estimateHeaderId, List<Account> accountList) {
        try {

            List<Estimate_Line_Item__c> estimateLineList = new List<Estimate_Line_Item__c>();

            if (!accountList.isEmpty()) {
                for (Account acc : accountList) {

                    Estimate_Line_Item__c estimateitem=new Estimate_Line_Item__c();
                    estimateitem.Account__c = acc.Id;
                    estimateitem.Estimate_Header__c =estimateHeaderId;
                    estimateitem.Status__c =STATUS_WAITING;
                    estimateLineList .add(estimateitem);
                }
            }
            System.debug(estimateLineList);
            return estimateLineList ;
        }catch (RSP_Custom_Exception exc) {
            RSP_Logging_Util.logerror('RSP_Estimate_Header_Helper','createEstimateLines', exc);
            return null;
        }
    }
    
    public static void initiateEstimateLineItemProcess(Map<Id, Estimate_Header__c> oldEstimateHeaderMap, Map<Id, Estimate_Header__c> newEstimateHeaderMap) {
        try {
            Id startedEstimateHeader;

            if (!newEstimateHeaderMap.keySet().isEmpty()) {
                for (Estimate_Header__c eHeader : newEstimateHeaderMap.values()) {
                    if (eHeader.Status__c != oldEstimateHeaderMap.get(eHeader.Id).Status__c && eHeader.Status__c == STATUS_READY_TO_PROCESS) {
                        startedEstimateHeader = eHeader.Id;
                    }
                }
                if (startedEstimateHeader!= null) {
                    List<Estimate_Line_Item__c> estimateLineItemList = RSP_Estimate_Service.initialEstimateLineItem(startedEstimateHeader);
                    if (!estimateLineItemList.isEmpty()){
                        Database.executeBatch(new RSP_Estimate_Line_Item_Batch(estimateLineItemList,newEstimateHeaderMap.values()[0]), RSP_Utils.GetBatchSize(RSP_Utils.SETTLEMENT_RUN_BATCH));
                    }else{
                        List<Estimate_Header__c> settlementCompleted = RSP_Estimate_Service.queryCompletedEstimateHeader(startedEstimateHeader);
                        if(!settlementCompleted.isEmpty()){
                            settlementCompleted[0].Status__c = STATUS_SETTLEMENT_RUN_COMPLETE;
                            update settlementCompleted;
                        }
                    }
                }
            }

        }catch (RSP_Custom_Exception exc) {
            RSP_Logging_Util.logerror('RSP_Estimate_Header_Helper','initiateEstimateLineItemProcess', exc);
        }
    }
    
    public static Map<Id, Decimal> runSettlement(List<c2g__codaTransactionLineItem__c> tliList, Map<Id, Estimate_Line_Item__c> estimateLineMap){
        try{
            Map<Id, Decimal> amountMap = new Map<Id, Decimal>();
            for(c2g__codaTransactionLineItem__c tli : tliList){
                tli.Settlement_Line__c = estimateLineMap.get(tli.c2g__Account__c).Id;
                Decimal tliAmount = 0;
                if(tli.c2g__HomeValue__c != null)
                    tliAmount = tli.c2g__HomeValue__c;
                if(!amountMap.containsKey(tli.c2g__Account__c)){
                    amountMap.put(tli.c2g__Account__c, tliAmount);
                }else{
                    amountMap.put(tli.c2g__Account__c, amountMap.get(tli.c2g__Account__c) + tliAmount);
                }
            }
            RSP_Estimate_Service.updateTransactionLineItems(tliList);
            return amountMap;
        }catch (RSP_Custom_Exception exc) {
            RSP_Logging_Util.logerror('RSP_Estimate_Header_Helper','runSettlement', exc);
            return null;
        }
    }
    
}