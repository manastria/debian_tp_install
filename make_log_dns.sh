#!/usr/bin/env bash

cat > /etc/bind/named.conf.sample <<"EOF"
include "/etc/bind/named.conf.log";

acl goodclients {
    10.0.0.0/8;
    192.168.0.0/16;
    172.16.0.0/12;
	172.25.0.0/16;
    localhost;
    localnets;
};

options {
    directory "/var/cache/bind";

    dnssec-validation no;
    dnssec-enable no;

	// recursion : le serveur est-il récursif ? Répondre aux résolveurs pour les zones dont il n'a pas autorité.
    recursion yes;
    allow-recursion { goodclients; };
    allow-query     { any; };

	// Interdit les transferts de zone par défaut (requetes AXFR)
	allow-transfer {"none";};

    listen-on-v6 { none; };

    forwarders {
        192.168.1.1;
        172.16.0.1;
        172.25.99.3;
        172.25.99.6;
    };
};

// zone "." {
//     type hint;
//     file "/usr/share/dns/root.hints";
// };

zone "10.in-addr.arpa" in {
        type master;
        file "/etc/bind/db.10";
};

zone "168.192.in-addr.arpa" in {
        type master;
        file "/etc/bind/db.192.168";
};

zone "25.172.in-addr.arpa" in {
        type master;
        file "/etc/bind/db.172.25";
};


zone "demo.manastria.eu" {
    type master;
    file "/etc/bind/db.demo.manastria.eu";
};
EOF


cat > /etc/bind/named.conf.log <<"EOF"
logging {
     channel default_log {
          file "/var/log/bind/default" versions 3 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
     channel auth_servers_log {
          file "/var/log/bind/auth_servers" versions 100 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
     channel dnssec_log {
          file "/var/log/bind/dnssec" versions 3 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
     channel zone_transfers_log {
          file "/var/log/bind/zone_transfers" versions 3 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
     channel ddns_log {
          file "/var/log/bind/ddns" versions 3 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
     channel client_security_log {
          file "/var/log/bind/client_security" versions 3 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
     channel rate_limiting_log {
          file "/var/log/bind/rate_limiting" versions 3 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
     channel rpz_log {
          file "/var/log/bind/rpz" versions 3 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
     channel dnstap_log {
          file "/var/log/bind/dnstap" versions 3 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
//
// Si vous avez défini la catégorie " queries " et que vous ne souhaitez pas que la journalisation des requêtes soit activée par défaut, assurez-vous d'ajouter l'option " querylog no ; " - alors vous pourrez activer (et désactiver) la journalisation des requêtes en utilisant la commande " rndc querylog ".

     channel queries_log {
          file "/var/log/bind/queries" versions 600 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity info;
     };
//
// Ce canal est dynamique de sorte que lorsque le niveau de débogage est augmenté en utilisant rndc pendant que le serveur fonctionne, des informations supplémentaires seront enregistrées sur les requêtes qui échouent.  Les autres informations de débogage pour d'autres catégories seront envoyées au canal default_debug (qui est également dynamique), mais sans affecter la journalisation normale.
//
     channel query-errors_log {
          file "/var/log/bind/query-errors" versions 5 size 20m;
          print-time yes;
          print-category yes;
          print-severity yes;
          severity dynamic;
     };
//
// C'est le canal syslog par défaut, défini ici pour plus de clarté.  Vous n'êtes pas obligé de l'utiliser si vous préférez faire des logs sur vos propres canaux. Il envoie au démon syslog, et n'envoie que les messages enregistrés d'informations prioritaires et plus. (Les options d'impression de l'heure, de la catégorie et de la gravité ne sont pas par défaut).
//
     channel default_syslog {
          print-time yes;
          print-category yes;
          print-severity yes;
          syslog daemon;
          severity info;
     };
//
// C'est le canal de sortie de débogage par défaut, défini ici pour plus de clarté.
// Vous pouvez redéfinir la destination de la sortie si elle ne correspond pas
// aux plans de journalisation de votre administration système locale.
// C'est également un canal spécial qui ne produit une sortie que si le niveau
// de débogage est non nul.
//
     channel default_debug {
          print-time yes;
          print-category yes;
          print-severity yes;
          file "named.run";
          severity dynamic;
     };
//
// Enregistrez les éléments de base dans le syslog et le journal par défaut :
//
     category default { default_syslog; default_debug; default_log; };
     category config { default_syslog; default_debug; default_log; };
     category dispatch { default_syslog; default_debug; default_log; };
     category network { default_syslog; default_debug; default_log; };
     category general { default_syslog; default_debug; default_log; };
//
// Depuis BIND 9.12 et les versions plus récentes, vous pouvez diriger la journalisation du chargement de zone vers un autre canal avec la nouvelle catégorie pour le chargement de zone.  Si cela est utile, configurez d'abord le nouveau canal, puis modifiez la ligne ci-dessous pour y diriger la catégorie au lieu de la diriger vers syslog et le journal par défaut :
//
//     category zoneload { default_syslog; default_debug; default_log; };
//
// Enregistrer les messages relatifs à ce que nous avons reçu des serveurs faisant autorité pendant la récursion (si les serveurs boiteux et les edns-disabled obscurcissent d'autres messages, ils peuvent être envoyés sur leur propre canal ou être annulés).  Parfois, ces messages de log seront utiles pour rechercher pourquoi certains domaines ne sont pas résolus ou ne sont pas résolus de manière fiable
//
     category resolver { auth_servers_log; default_debug; };
     category cname { auth_servers_log; default_debug; };
     category delegation-only { auth_servers_log; default_debug; };
     category lame-servers { auth_servers_log; default_debug; };
     category edns-disabled { auth_servers_log; default_debug; };
//
// Journaliser les problèmes avec le DNSSEC :
//
     category dnssec { dnssec_log; default_debug; };
//
// Enregistrer tous les messages relatifs à la propagation de la zone faisant autorité
//
     category notify { zone_transfers_log; default_debug; };
     category xfer-in { zone_transfers_log; default_debug; };
     category xfer-out { zone_transfers_log; default_debug; };
//
// Journaliser tous les messages relatifs aux mises à jour dynamiques des données de la zone DNS :
//
     category update{ ddns_log; default_debug; };
     category update-security { ddns_log; default_debug; };
//
// Journaliser tous les messages relatifs à l'accès et à la sécurité des clients. (Il existe une catégorie supplémentaire " unmatched " qui est envoyée par défaut à null mais qui peut être ajoutée ici si vous souhaitez que plus d'une ligne de résumé soit journalisée pour les échecs de correspondance d'une vue).
//
     category client{ client_security_log; default_debug; };
     category security { client_security_log; default_debug; };
//
// Log together all messages that are likely to be related to rate-limiting. This includes RRL (Response Rate Limiting) - usually deployed on authoritative servers and fetches-per-server|zone.  Note that it does not include logging of changes for clients-per-query (which are logged in category resolver).  Also note that there may on occasions be other log messages emitted by the database category that don’t relate to rate-limiting behaviour by named.
// Journaliser tous les messages qui sont susceptibles d'être liés à la limitation des débits. Cela comprend les RRL (Response Rate Limiting) - généralement déployés sur des serveurs faisant autorité et les fetches par serveur/zone.  Notez qu'il n'inclut pas la journalisation des changements pour les clients par requête (qui sont journalisés dans le résolveur de catégories).  Notez également qu'il peut y avoir à l'occasion d'autres messages journalisés émis par la catégorie de base de données qui n'ont pas trait au comportement de limitation du taux de réponse par nom.
//
     category rate-limit { rate_limiting_log; default_debug; };
     category spill { rate_limiting_log; default_debug; };
     category database { rate_limiting_log; default_debug; };
//
// Log DNS-RPZ (Response Policy Zone) messages (if you are not using DNS-RPZ then you may want to comment out this category and associated channel)
//
     category rpz { rpz_log; default_debug; };
//
// Log messages relating to the "dnstap" DNS traffic capture system  (if you are not using dnstap, then you may want to comment out this category and associated channel).
//
     category dnstap { dnstap_log; default_debug; };
//
// If you are running a server (for example one of the Internet root nameservers) that is providing RFC 5011 trust anchor updates, then you may be interested in logging trust anchor telemetry reports that your server receives to analyze anchor propagation rates during a key rollover.  If this would be useful then firstly, configure the new channel, and then un-comment and the line below to direct the category there instead of to syslog and default log:
//
//
     category trust-anchor-telemetry { default_syslog; default_debug; default_log; };
//
// If you have the category ‘queries’ defined, and you don’t want query logging by default, make sure you add option ‘querylog no;’ - then you can toggle query logging on (and off again) using command ‘rndc querylog’
//
     category queries { queries_log; };
//
// This logging category will only emit messages at debug levels of 1 or higher - it can be useful to troubleshoot problems where queries are resulting in a SERVFAIL response.
//
     category query-errors {query-errors_log; };
};
EOF


cat > /etc/apparmor.d/local/usr.sbin.named <<"EOF"
/var/log/bind/** rw,
#added line here
/var/log/bind/* rw,
/var/log/bind/ rw,
EOF

apparmor_parser -r /etc/apparmor.d/usr.sbin.named


mkdir -p /var/log/bind
chown -R bind:root /var/log/bind
chmod 775 -R /var/log/bind


# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
