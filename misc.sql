# Get all transactions from a cash account
select * from transactions where cashacct=$idnum

# update value in cash account
update cashaccts set amt = amt+$num where id=$idnum