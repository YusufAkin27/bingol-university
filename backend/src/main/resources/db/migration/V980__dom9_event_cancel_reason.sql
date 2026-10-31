-- T-049: organizator iptalinde (yonetici iptalinden ayri) katilimciya gosterilecek neden.
ALTER TABLE user_event ADD COLUMN cancel_reason VARCHAR(300);
