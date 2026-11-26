-- Jalankan sekali di Supabase > SQL Editor. Anggota bisa mengganti PIN sendiri.
create or replace function member_change_pin(p_pin text, p_new text) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare m record;
begin
  delete from attempts where ts < now() - interval '1 day';
  if (select count(*) from attempts where ts > now() - interval '10 minutes') >= 30 then
    return jsonb_build_object('ok', false, 'error', 'locked');
  end if;
  select id into m from members where pin_hash = crypt(coalesce(p_pin,''), pin_hash) limit 1;
  if not found then
    insert into attempts default values;
    return jsonb_build_object('ok', false, 'error', 'bad');
  end if;
  if coalesce(p_new,'') !~ '^[0-9]{6}$' then return jsonb_build_object('ok', false, 'error', 'pin_format'); end if;
  if p_new = p_pin then return jsonb_build_object('ok', false, 'error', 'same'); end if;
  if _pin_taken(p_new, m.id) then
    insert into attempts default values;  -- dihitung sebagai percobaan gagal agar PIN orang lain tidak bisa ditebak lewat fitur ini
    return jsonb_build_object('ok', false, 'error', 'pin_taken');
  end if;
  update members set pin_hash = crypt(p_new, gen_salt('bf')) where id = m.id;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function member_change_pin(text, text) to anon;
