# $Id: SguildGenericDB.tcl,v 1.8 2005/03/08 20:35:03 bamm Exp $ #

proc GetUserID { username } {
  set uid [FlatDBQuery "SELECT uid FROM user_info WHERE username='$username'"]
  if { $uid == "" } {
    DBCommand\
     "INSERT INTO user_info (username, last_login) VALUES ('$username', '[GetCurrentTimeStamp]')"
    set uid [FlatDBQuery "SELECT uid FROM user_info WHERE username='$username'"]
  }
  return $uid
}
                                                                                                     
proc InsertHistory { sid cid uid timestamp status comment} {
  if {$comment == "none"} {
    DBCommand "INSERT INTO history (sid, cid, uid, timestamp, status) VALUES ( $sid, $cid, $uid, '$timestamp', $status)"
  } else {
    DBCommand "INSERT INTO history (sid, cid, uid, timestamp, status, comment) VALUES ( $sid, $cid, $uid, '$timestamp', $status, '$comment')"
  }
}
                                                                                                     
proc GetSensorID { sensorName } {

    # For now we query the DB everytime we need the sid.
    set sid [FlatDBQuery "SELECT sid FROM sensor WHERE hostname='$sensorName'"]

    return $sid

}

proc GetMaxCid { sid } {

    set cid [FlatDBQuery "SELECT MAX(cid) FROM event WHERE sid=$sid"]
    return $cid

}

proc ExecDB { socketID query } {
  global DBNAME DBUSER DBPASS DBPORT DBHOST
    if { [lindex $query 0] == "OPTIMIZE" } {
        SendSystemInfoMsg sguild "Table Optimization beginning, please stand by"
    }
  InfoMessage "Sending DB Query: $query"
  if { $DBPASS == "" } {
      set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
      set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  if [catch {mysqlexec $dbSocketID $query} execResults] {
        catch {SendSocket $socketID "InfoMessage \{ERROR running query, perhaps you don't have permission. Error:$execResults\}"} tmpError
  } else {
      if { [lindex $query 0] == "DELETE" } {
          catch {SendSocket $socketID "InfoMessage Query deleted $execResults rows."} tmpError
      } elseif { [lindex $query 0] == "OPTIMIZE" } {
          catch {SendSocket $socketID "InfoMessage Database Command Completed."} tmpError
          SendSystemInfoMsg sguild "Table Optimization Completed."
      } else {
          catch {SendSocket $socketID "InfoMessge Database Command Completed."} tmpError
      }
  }
  mysqlclose $dbSocketID
}

proc QueryDB { socketID clientWinName query } {
  global mainWritePipe
  global DBNAME DBUSER DBPASS DBPORT DBHOST
                                                                                                     
  # Just pass the query to queryd.
  if { $DBPASS == "" } {
    set dbCmd "mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT"
  } else {
    set dbCmd "mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS"
  }
  puts $mainWritePipe [list $socketID $clientWinName $query $dbCmd]
  flush $mainWritePipe
}
proc FlatDBQuery { query } {
  global DBNAME DBUSER DBPORT DBHOST DBPASS
                                                                                                     
  if { $DBPASS == "" } {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  set queryResults [mysqlsel $dbSocketID $query -flatlist]
  mysqlclose $dbSocketID
  return $queryResults
}
# type can be list or flatlist.
# list returns { 1 foo } { 2 bar } { 3 fu }
# flatlist returns { 1 foo 2 bar 3 fu } 
proc MysqlSelect { query { type {list} } } {

    global DBNAME DBUSER DBPORT DBHOST DBPASS

    if { $DBPASS == "" } {
        set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
    } else {
        set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
    }

    if { $type == "flatlist" } {
        set queryResults [mysqlsel $dbSocketID $query -flatlist]
    } else {
         set queryResults [mysqlsel $dbSocketID $query -list]
    }
    mysqlclose $dbSocketID
    return $queryResults

}

proc DBCommand { query } {
  global DBNAME DBUSER DBPORT DBHOST DBPASS
                                                                                                     
  if { $DBPASS == "" } {
    set dbCmd [list mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbCmd [list mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
                                                                                                     
  # Connect to the DB
  if { [ catch {eval $dbCmd} dbSocketID ] } {
    ErrorMessage "ERROR Connecting to the DB: $dbSocketID"
  }
                                                                                                     
  if [catch {mysqlexec $dbSocketID $query} tmpError] {
      ErrorMessage "ERROR Execing DB cmd: $query Error: $tmpError"
  }
  catch {mysqlclose $dbSocketID}
  return
}
proc UpdateDBStatusList { whereTmp timestamp uid status } {
  global DBNAME DBUSER DBPORT DBHOST DBPASS
  set updateString "UPDATE event SET status=$status, last_modified='$timestamp', last_uid='$uid' WHERE $whereTmp"
  if { $DBPASS == "" } {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  set execResults [mysqlexec $dbSocketID $updateString]
  mysqlclose $dbSocketID
  return $execResults
}
proc UpdateDBStatus { eventID timestamp uid status } {
  global DBNAME DBUSER DBPORT DBHOST DBPASS
  set sid [lindex [split $eventID .] 0]
  set cid [lindex [split $eventID .] 1]
  set updateString\
   "UPDATE event SET status=$status, last_modified='$timestamp', last_uid='$uid' WHERE sid=$sid AND cid=$cid"
  if { $DBPASS == "" } {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  set execResults [mysqlexec $dbSocketID $updateString]
  mysqlclose $dbSocketID
}

proc SafeMysqlExec { query } {

    global MAIN_DB_SOCKETID

    if [catch { mysqlexec $MAIN_DB_SOCKETID $query } execResults ] {
                                                                                                                       
        LogMessage "DB Error during:\n$query\n: $execResults"
        set ERROR 1
                                                                                                                       
    } else {

        set ERROR 0
                                                                                                                       
    }

    if { $ERROR } {
        return -code error $execResults
    } else {
        return
    }

}

proc InsertEventHdr { sid cid u_event_id u_event_ref u_ref_time msg sig_gen \
                      sig_id sig_rev timestamp priority class_type status   \
                      dec_sip dec_dip ip_proto ip_ver ip_hlen ip_tos ip_len \
                      ip_id ip_flags ip_off ip_ttl ip_csum icmp_type        \
                      icmp_code src_port dst_port } {

    # Event columns we are INSERTing
    set tmpTables \
         "sid, cid, unified_event_id, unified_event_ref, unified_ref_time,  \
         signature, signature_gen, signature_id, signature_rev, timestamp,  \
         priority, class, status, src_ip, dst_ip, ip_proto, ip_ver, ip_hlen,\
         ip_tos, ip_len, ip_id, ip_flags, ip_off, ip_ttl, ip_csum"
                                                                                                                       
    # And their corresponding values.
    set tmpValues \
         "$sid, $cid, $u_event_id, $u_event_ref, '$u_ref_time', '$msg',  \
         '$sig_gen', '$sig_id', '$sig_rev', '$timestamp', '$priority',   \
         '$class_type', '$status', '$dec_sip', '$dec_dip', '$ip_proto',  \
         '$ip_ver', '$ip_hlen', '$ip_tos', '$ip_len', '$ip_id',          \
         '$ip_flags', '$ip_off', '$ip_ttl', '$ip_csum'"
                                                                                                                       
    # ICMP, TCP, & UDP have extra columns
    if { $ip_proto == "1" } {
                                                                                                                       
        # ICMP event
        set tmpTables "${tmpTables}, icmp_type, icmp_code"
        set tmpValues "${tmpValues}, '$icmp_type', '$icmp_code'"
                                                                                                                       
    } elseif { $ip_proto == "6" || $ip_proto == "17" } {
                                                                                                                       
        # TCP || UDP event
        set tmpTables "${tmpTables}, src_port, dst_port"
        set tmpValues "${tmpValues}, '$src_port', '$dst_port'"

    }
 
    # The final INSERT gets built
    set tmpQuery "INSERT INTO event ($tmpTables) VALUES ($tmpValues)"

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }

}

proc InsertUDPHdr { sid cid udp_len udp_csum } {

    set tmpQuery "INSERT INTO udphdr (sid, cid, udp_len, udp_csum) \
                  VALUES ($sid, $cid, $udp_len, $udp_csum)"

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }
}

proc InsertTCPHdr { sid cid tcp_seq tcp_ack tcp_off tcp_res \
                    tcp_flags tcp_win tcp_csum tcp_urp } {

    set tmpQuery "INSERT INTO tcphdr (sid, cid, tcp_seq, tcp_ack, \
                  tcp_off, tcp_res, tcp_flags, tcp_win, tcp_csum, tcp_urp) \
                  VALUES ($sid, $cid, $tcp_seq, $tcp_ack, $tcp_off, \
                  $tcp_res, $tcp_flags, $tcp_win, $tcp_csum, $tcp_urp)"
                 
    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }

}

proc InsertICMPHdr { sid cid icmp_csum icmp_id icmp_seq } {

    set tmpTables "sid, cid, icmp_csum"
    set tmpValues "$sid, $cid, $icmp_csum"

    if { $icmp_id != "" } {
        set tmpTables "$tmpTables, icmp_id"
        set tmpValues "$tmpValues, $icmp_id"
    }

    if { $icmp_seq != "" } {
        set tmpTables "$tmpTables, icmp_seq"
        set tmpValues "$tmpValues, $icmp_seq"
    }

    set tmpQuery "INSERT INTO icmphdr ($tmpTables)  VALUES ($tmpValues)"

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }

}

proc InsertDataPayload { sid cid data_payload } {

    set tmpQuery "INSERT INTO data (sid, cid, data_payload) \
                  VALUES ($sid, $cid, '$data_payload')"

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }

}
