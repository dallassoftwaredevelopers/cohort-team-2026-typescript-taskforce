-- DC-20: bill lifecycle and invoice rules, on top of the DC-16 baseline.
-- Adds vendor_id, invoice_number, status and date_received to bills (names and types
-- from the ERD). The vendor_id foreign key is left to DC-19.

alter table public.bills
  add column vendor_id integer,
  add column invoice_number varchar,
  add column status varchar,
  add column date_received timestamp;

-- Invoice numbers are stored trimmed, and a blank one is stored as NULL.
create function public.bills_normalize_invoice_number()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.invoice_number := nullif(btrim(new.invoice_number), '');
  return new;
end
$$;

create trigger bills_normalize_invoice_number
  before insert or update of invoice_number on public.bills
  for each row execute function public.bills_normalize_invoice_number();

-- An invoice number is unique per vendor, ignoring case. The same number can appear
-- at different vendors, and any number of bills can have none.
create unique index bills_vendor_id_invoice_number_key
  on public.bills (vendor_id, lower(invoice_number));

-- status is the bill's lifecycle; a saved but unsubmitted bill is a draft.
-- Existing bills had no status, so they start as drafts.
update public.bills set status = 'draft';
alter table public.bills
  alter column status set default 'draft',
  alter column status set not null,
  add constraint bills_status_check check (status in (
    'draft', 'pending_approval', 'approval_denied', 'pending_payment',
    'processing', 'payment_success', 'payment_failed')),
  -- A bill needs an invoice number once it leaves draft.
  add constraint bills_invoice_number_required_check
    check (status = 'draft' or invoice_number is not null);

-- date_received is stored in UTC like created_at. It defaults to the insert time, can be
-- edited or backdated later, and can't be in the future. Existing bills take created_at.
update public.bills set date_received = created_at;
alter table public.bills
  alter column date_received set default (now() at time zone 'UTC'),
  alter column date_received set not null,
  add constraint bills_date_received_not_future_check
    check (date_received <= (now() at time zone 'UTC'));
