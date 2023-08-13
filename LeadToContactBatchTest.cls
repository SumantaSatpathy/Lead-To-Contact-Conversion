/*
Test Class Name          : LeadToContactBatchTest
Date of creation         : 31/07/2023
Developer                : Sumanta Satpathy
Apex Class               : LeadToContactBatch
Requirement/Project Name : 
Requirement/Description  : Test class for 'LeadToContactBatch' apex class
Last Modified            : 02/08/2023
                         
*/
@IsTest
public class LeadToContactBatchTest {

    @testSetup
    static void setupTestData() {
        // Create test data shared by all test methods
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create a common contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'test@example.com'
            //AccountId = testAccount.Id
        );
        insert testContact;
        // Create a common product
        Product2 product = ODY_CSTestDataFactory.insertProd();
        
        // Create test lead with matching contact
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            LeadSource = 'DAVIS',
            Status = 'Open',
            Company = 'Test Company',
            Email = 'test@example.com',
            Event_Partner_Opt_In__c = 'Yes',
            IsConverted = false,
            To_Be_Deleted__c = false
        );
        insert testLead;
        Lead testLead2 = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            LeadSource = 'DAVIS',
            Status = 'Open',
            Company = 'Test Company',
            Email = 'test@example.com',
            Event_Partner_Opt_In__c = 'Yes',
            IsConverted = false,
            To_Be_Deleted__c = true
        );
        insert testLead2;

        // Create common opportunities
        Opportunity testOpportunity1 = new Opportunity(
            Name = 'Test Opportunity 1',
            StageName = 'Prospecting',
            TF_Donor__c = testLead.Id,
            TotalOpportunityQuantity = 10,
            Product_Name__c = product.Id,
            CloseDate = System.today(),
            Event_Date__c = System.today(),
            Amount = 100
        );
        insert testOpportunity1;
        
        Opportunity testOpportunity2 = new Opportunity(
            Name = 'Test Opportunity 2',
            StageName = 'Prospecting',
            TF_Donor__c = testLead2.Id,
            TotalOpportunityQuantity = 10,
            Product_Name__c = product.Id,
            CloseDate = System.today(),
            Event_Date__c = System.today(),
            Amount = 100
        );
        insert testOpportunity2;
    }

    @IsTest
    static void testBatchWithMatchingContact() {
        // Get the common test data
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Lead testLead = [Select Id from Lead where Email = 'test@example.com' and To_Be_Deleted__c = true LIMIT 1];
        Opportunity testOpportunity = [Select Id,Product_Name__c from Opportunity where Name = 'Test Opportunity 2' LIMIT 1];
        
        // Start the batch
        Test.startTest();
        Database.executeBatch(new LeadToContactBatch());
        Test.stopTest();

        // Assertions
        List<Lead> deletedLeads = [SELECT Id FROM Lead WHERE Id = :testLead.Id AND To_Be_Deleted__c = true];
        System.assertEquals(1, deletedLeads.size(), 'The lead should have been marked as to be deleted.');

        List<Contact> updatedContacts = [SELECT Id FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals(1, updatedContacts.size(), 'The contact should have been linked to the converted lead.');

        List<Opportunity> updatedOpportunities = [SELECT Id, npsp__Primary_Contact__c FROM Opportunity WHERE TF_Donor__c = :testLead.Id];
        System.assertEquals(1, updatedOpportunities.size(), 'The opportunity should have been updated with the converted contact as the primary contact.');
        
    }

    @IsTest
    static void testBatchWithoutMatchingContact() {
        // Get the common test data
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

       // Create test lead without a matching contact
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            LeadSource = 'DAVIS',
            Status = 'Open',
            Company = 'Test Company',
            Email = 'test1@example.com',
            Event_Partner_Opt_In__c = 'No',
            IsConverted = false,
            To_Be_Deleted__c = false
        );
        insert testLead;

        // Start the batch
        Test.startTest();
        Database.executeBatch(new LeadToContactBatch());
        Test.stopTest();

        // Assertions
        List<Lead> deletedLeads = [SELECT Id FROM Lead WHERE Id = :testLead.Id AND To_Be_Deleted__c = true];
        System.assertEquals(0, deletedLeads.size(), 'The lead should not have been marked as to be deleted because there is no matching contact.');
    }

    @IsTest
    static void testBatchWithOpportunityAndProduct() {
        // Get the common test data
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];
        Lead testLead = [Select Id from Lead where Email = 'test@example.com' LIMIT 1];
        Opportunity testOpportunity = [Select Id,Product_Name__c from Opportunity where Name = 'Test Opportunity 1' LIMIT 1];

        // Create PriceBookEntry for the product
        Pricebook2 pricebookId = new Pricebook2(Name = 'Standard Price Book', IsActive = true);
        insert pricebookId;
        PriceBookEntry testPriceBookEntry = new PriceBookEntry(
            Pricebook2Id = pricebookId.Id,
            Product2Id = testOpportunity.Product_Name__c,
            UnitPrice = 30
        );
        insert testPriceBookEntry;

        // Inserting order
        Order ord = new Order();
        ord.Contact__c = testContact.Id;
        ord.AccountId = testAccount.Id;
        ord.EffectiveDate = System.today();
        ord.Status = 'Closed';
        ord.Pricebook2Id = pricebookId.Id;
        ord.Type = 'Renewable Order';
        ord.OpportunityId = testOpportunity.Id;
        insert ord;

        // Start the batch
        Test.startTest();
        Database.executeBatch(new LeadToContactBatch());
        Test.stopTest();

        // Assertions
        List<Order> insertedOrders = [SELECT Id FROM Order WHERE OpportunityId = :testOpportunity.Id];
        System.assertEquals(2, insertedOrders.size(), 'An order should have been inserted for the opportunity.');

        List<OrderItem> insertedOrderItems = [SELECT Id FROM OrderItem WHERE OrderId = :insertedOrders[1].Id];
        System.assertEquals(1, insertedOrderItems.size(), 'An order item should have been inserted for the order.');
    }
}