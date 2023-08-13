/*
Class Name               : LeadToContactBatch
Date of creation         : 15/07/2023
Developer                : Sumanta Satpathy
Test Class               : LeadToContactBatchTest
Requirement/Project Name : 
Requirement/Description  :If a contact exists with same name and email id as in lead, then mark the lead is closed and converted.
						   Link the renewable of the lead to the matched contact and create  an order and oderitem for the product mentioned in the renewable
Last Modified            : 31/07/2023
History                  : 31/07/2023 - Added batch query to metadata (Lead_To_Contact_Batch), added constructor
                         
*/
public class LeadToContactBatch implements Database.Batchable<SObject>,Database.Stateful {
    List<Lead> leadsToBeDeleted = new List<Lead>();
    List<Contact> existingContacts = new List<Contact>();
    public NMM_Batch_Metadata__mdt mdt;
    //getting the SOQL from the metadata
    public LeadToContactBatch()
    {
        this.mdt = [SELECT MasterLabel, NMM_Batch_Query__c, NM_Batch_Size__c,NM_Active__c FROM NMM_Batch_Metadata__mdt WHERE MasterLabel =: 'Lead_To_Contact_Batch' LIMIT 1];
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
       
        return Database.getQueryLocator(mdt.NMM_Batch_Query__c);
    }
    
    public void execute(Database.BatchableContext context, List<Lead> scope) {
        List<Lead> newConvertedLeads = new List<Lead>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        List<Order> ordersToInsert = new List<Order>();
        List<OrderItem> orderItemsToInsert = new List<OrderItem>();
        List<PriceBookEntry> priceBookEntryList = new List<PriceBookEntry>();         
        
        for (Lead lead : scope) {
            //fetching the opportunities of the lead
            List<Opportunity> oppsOfLead = [SELECT Id, TF_Donor__c, ContactId, TotalOpportunityQuantity, Product_Name__c, Amount, Product_Name__r.Name,Event_Date__c,CloseDate,opportunity.npsp__Primary_Contact__r.AccountId FROM Opportunity WHERE TF_Donor__c = :lead.Id];
            //fetching the matching contact of the lead            
            List<Contact> matchingContacts = [SELECT Id, Email, AccountId FROM Contact WHERE FirstName = :lead.FirstName AND LastName = :lead.LastName AND Email = :lead.Email LIMIT 1];
            //creating lead with Status = 'Closed - Converted' and marking the existing lead for deletion process        
            if (!matchingContacts.isEmpty()) {
                Contact existingContact = matchingContacts[0];            	
                Lead convertedLead = new Lead();
                convertedLead.FirstName = lead.FirstName;
                convertedLead.LastName = lead.LastName;
                convertedLead.LeadSource = lead.LeadSource;
                convertedLead.Status = 'Closed - Converted';
                convertedLead.Company = lead.Company;
                convertedLead.Email = lead.Email;
                convertedLead.IsConverted = true;
                convertedLead.ConvertedAccountId = existingContact.AccountId;
                convertedLead.ConvertedContactId = existingContact.Id;
                
                lead.To_Be_Deleted__c = true;
                
                existingContacts.add(existingContact);
                newConvertedLeads.add(convertedLead);
                //Updating Opportunity records with Matched contact ID and Account ID
                if (!oppsOfLead.isEmpty()) {
                    for (Opportunity opportunity : oppsOfLead) {
                        opportunity.npsp__Primary_Contact__c = existingContact.Id;
                        opportunity.AccountId = existingContact.AccountId;
                        oppsToUpdate.add(opportunity);
                        
                    }
                }
                
                leadsToBeDeleted.add(lead);
            }
        }        
        try {
            update scope;
            insert newConvertedLeads;
            update oppsToUpdate;
        } catch (Exception e) {
            System.debug('An error occurred: ' + e.getMessage());
        }
        //creating order by taking the details from the opportunity
        if (!existingContacts.isEmpty() && !oppsToUpdate.isEmpty()) {
                for (Opportunity opportunity : oppsToUpdate) {
                        priceBookEntryList = [SELECT Id, Name, Product2.Name, Product2.ProductCode, PriceBook2.Name, Product2Id, Pricebook2Id FROM PriceBookEntry WHERE Product2Id = :opportunity.Product_Name__c AND PriceBook2.Name = 'Standard Price Book'];
                        
                        for (PriceBookEntry pbe : priceBookEntryList) {
                            if (pbe.Product2Id == opportunity.Product_Name__c) {
                                Order order = new Order();
                                order.Type = 'Purchase Order';
                                order.Contact__c = opportunity.npsp__Primary_Contact__c;
                                order.AccountId = opportunity.AccountId;
                                order.OpportunityId = opportunity.Id;
                                order.Status = 'Paid';
                                order.EffectiveDate = opportunity.CloseDate;
                                order.Pricebook2Id = pbe.Pricebook2Id;                                
								date d = opportunity.CloseDate;
                                order.Order_Date__c = datetime.newInstance(d, Time.newInstance(00,00,00,00));
                                ordersToInsert.add(order); 
                            }
                        }
                }         
            if (!ordersToInsert.isEmpty()) {
                try{
                    insert ordersToInsert;
                } catch (Exception e) {
            		System.debug('An error occurred: ' + e.getMessage());
        		}
            }
			// Creating order item for the oder inserted            
            for (Order order : ordersToInsert) {
                for (Opportunity opportunity : oppsToUpdate) {
                    if (order.OpportunityId == opportunity.Id) {
                        for (PriceBookEntry pbe : priceBookEntryList) {
                            OrderItem orderItem = new OrderItem();
                            orderItem.OrderId = order.Id;
                            orderItem.Product2Id = pbe.Id;
                            orderItem.Quantity = opportunity.TotalOpportunityQuantity;
                            orderItem.UnitPrice = opportunity.Amount;
                            
		                             
                            orderItemsToInsert.add(orderItem); 
                        }
                    }
                }
            }
            if (!orderItemsToInsert.isEmpty()) {
                try{
                    System.debug('orderItemsToInsert: ' + orderItemsToInsert.size());
                    insert orderItemsToInsert;
                } catch (Exception e) {
            		System.debug('An error occurred: ' + e.getMessage());
        		}
            }           
        }
    }
    
    public void finish(Database.BatchableContext context) {
        // Perform any post-processing actions
        // Get the AsyncApexJob that represents the Batch job using the Id from the BatchableContext  
       /*AsyncApexJob a = [Select Id, Status, NumberOfErrors, JobItemsProcessed,TotalJobItems, CreatedBy.Email, ExtendedStatus from AsyncApexJob where Id = :context.getJobId()]; 
        system.debug('AsyncApexJob' + AsyncApexJob.Id);
        system.debug('leadsToBeDeleted inside finish'+ leadsToBeDeleted);
        */
        //delete old lead records
        if (!leadsToBeDeleted.isEmpty()) {
                try{
                    delete leadsToBeDeleted;
                } catch (Exception e) {
            		System.debug('An error occurred: ' + e.getMessage());
        		}
            }
        //system.debug('finish ends');
    }
}