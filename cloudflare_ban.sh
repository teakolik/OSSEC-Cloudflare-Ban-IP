#!/bin/sh
# 
# Açıklama: OSSEC ile Cloudflare Üzerinden Zararlı İstekleri Banlamak
#
# Script konumu: /var/ossec/active-response/cloudflare_ban.sh
# Sonrasında chmod +x cloudflare_ban.sh komutu vermeyi unutmayın!
# 
# Ossec SH Dosya Yolu /var/ossec/active-response/bin/cloudflare-ban.sh
# 
# OSSEC Conf /var/ossec/etc/ossec.conf Editleyin ve Aşağıdaki Kodları Giriniz.
# Command kısmına OSSEC'in Cloudflare_ban.sh scriptimizi çalıştırması için gerekli kodları giriyoruz.
# Time out süresi kullanabilmesi için yes değeri de veriyorum. 
# Koddaki srcip aynen kalsın! Script değil Source ip kısaltmasıdır :) 
#  <command>
#     <name>cloudflare_ban</name> 
#     <executable>cloudflare_ban.sh</executable>
#     <timeout_allowed>yes</timeout_allowed>
#     <expect>srcip</expect>
#  </command>
# 
# OSSEC Conf /var/ossec/etc/ossec.conf Editleyin ve Aşağıdaki Kodları Giriniz.
# Active Response'yi açarak Cloudflare_ban.sh scriptimizin hangi kurallarda tetikleneceğini yazıyoruz.
# Dikkat ederseniz birkaç örnek kural 31151,31152,31153,31154,31161,31164,31165,31104,31100 gibi aşağıda girdim. 
# Ayrıca timeout süresine 43200 saniye değeri ile 12 saat süre verdim. 
# 12 saat süre sonrasında blokelenen ip'yi Cloudflare üzerinden silecektir. 
#  <active-response>
#     <command>cloudflare_ban</command>
#     <location>server</location>
#     <rules_id>31151,31152,31153,31154,31161,31164,31165,31104,31100</rules_id>
#     <timeout>43200</timeout>
#  </active-response>

echo "Kötü Çocukların IP adreslerini Cloudflaye Göndermeye Başladık!"

# TANIMLAMALAR 
ACTION=$1
USER=$2
IP=$3
PWD=`pwd`
TOKEN='CLOUDFLAREPUBLICAPI'
USER='CLOUDFLAREÜYEEPOSTASI'
MODE='block' # Cloudflare'deki block veya challenge modu dilerseniz bloke etmeyebilirsiniz.
ACTIVERESPONSE='/var/ossec/logs/active-responses.log' # Active-Response loguna bloke ve deleteleri basacak

# Loglamayı Çağırıyoruz ve Active-response.log dosyasına script sonuçlarını yazdırıyoruz
echo "`date` $0 $1 $2 $3 $4 $5" >> $ACTIVERESPONSE

# IP Adresini Vermemiz Şart
if [ "x${IP}" = "x" ]; then
   echo "$0: Missing argument <action> <user> (ip)"
   exit 1;
fi

# Yaramaz Çocukların IPlerini CF APIye Ekliyoruz
if [ "x${ACTION}" = "xadd" ]; then
   curl -sSX POST "https://api.cloudflare.com/client/v4/user/firewall/access_rules/rules" \
   -H "X-Auth-Email: $USER" \
   -H "X-Auth-Key: $TOKEN" \
   -H "Content-Type: application/json" \
   --data "{\"mode\":\"$MODE\",\"configuration\":{\"target\":\"ip\",\"value\":\"$IP\"},\"notes\":\"OSSEC Blokesi\"}"
   exit 0;


# Timeout süremiz dolunca yaramaz çocukların IPlerini Siliyoruz ve blokelerini kaldırma işlemi. 
elif [ "x${ACTION}" = "xdelete" ]; then

# Cloudflarede blokeli olan IP'leri çağırıyoruz
   JSON=$(curl -sSX GET "https://api.cloudflare.com/client/v4/user/firewall/access_rules/rules?mode=$MODE&configuration_target=ip&configuration_value=$IP" \
   -H "X-Auth-Email: $USER" \
   -H "X-Auth-Key: $TOKEN" \
   -H "Content-Type: application/json")

# Cloudflareden süresi dolan yaramaz çocukların iplerinin blokelerini açıyoruz.  
   ID=$(echo $JSON | jq -r '.result[].id')
    
   curl -sSX DELETE "https://api.cloudflare.com/client/v4/user/firewall/access_rules/rules/$ID" \
   -H "X-Auth-Email: $USER" \
   -H "X-Auth-Key: $TOKEN" \
   -H "Content-Type: application/json"
   exit 0;

# Geçersiz Eylemler
else
   echo "$0: invalid action: ${ACTION}"
fi

exit 1;
