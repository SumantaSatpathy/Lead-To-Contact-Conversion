# Lead-To-Contact-Conversion
Mark a lead to Closed and Converted If a matching contact is present in Salesforce or Auto convert a lead if an existing contact is present
we must mark the lead to converted status if we find a similar contact in the contact object. So that the marketing team will follow the same person once, not twice. Along with that once a matching contact is found, then according to the data present in the related opportunity records an order and order item need to be created for the contact.

To achieve the lead-to-contact conversion automation we need write access on two system fields on the Lead object which are not enabled by default.

Fields are mentioned below:
ConvertedContactId & ConvertedAccountId

Above mentioned two fields are not visible in the object manager. So, we cannot grant access to the fields from the profile or permission set.
To get access we must follow the below steps mentioned in the link:

Link: Enable the permission 'Create Audit Fields' for standard profiles (salesforce.com)

Steps in brief:

Enablement of the 'Create Audit Fields' permission is needed for this operation:
•	
This can be achieved by firstly enabling the option 'Enable "Set Audit Fields upon Record Creation’ and "Update Records with Inactive Owners" User Permission' via Setup / User Interface.
•	Then assign the system permissions 'Set Audit Fields upon Record Creation' and 'Update Records with Inactive Owners' to the users who need them via profile or permission set.
https://help.salesforce.com/s/articleView?id=000334139&type=1

However, there are unfortunately some limitations of this feature that should be considered:

Unfortunately, it is not possible to edit or update audit fields after creation, nor manually, nor via API (so only can only be used by insert command, not via update/upsert). Even Salesforce Support cannot provide edit rights on system audit fields after the creation of a record - this is a limitation of our Salesforce!

As other users also noted this feature gap, there is an existing Idea that I recommend for the upvote process to make this limit even more transparent for our R&D team :
https://ideas.salesforce.com/s/idea/a0B8W00000GdoGzUAJ/once-audit-fields-are-turned-on-ability-to-use-dataloader-to-update

Implemented Solution:
The alternative solution is to reinsert (recreation) the records of given objects with the updated Audit Fields instead of updating the records - in our case, recreate the Lead record which needs to be converted to an existing Contact record with audit fields updated with the respective values and it may be possible to remove previously inserted lead record by marking as to be deleted= true. The deletion of the old record needs to be carried out in another transaction.

So, we may follow the Stateful Batch apex to achieve the solution.

Metadata details:


Metadata Name	Component details
Batch Apex :         	LeadToContactBatch
Test class :          LeadToContactBatchTest
Custom Metadata	:     NMM_Batch_Metadata__mdt >> Lead_To_Contact_Batch
Permission Set :     	Set_Audit_Fields_upon_Record_Creation



Batch apex to be run as data migration user with a batch size of 50

