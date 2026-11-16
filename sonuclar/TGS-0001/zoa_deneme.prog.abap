REPORT zoa_deneme.

* HR onayci hiyerarsisi karsilastirma: SAS/SAT (super) vs MIR7/FFI

TYPES: BEGIN OF ty_out,
         src        TYPE char10,
         level      TYPE zahom_level,
         sublevel   TYPE numc2,
         pernr      TYPE pernr_d,
         uname      TYPE syuname,
         emp_name   TYPE emnam,
         plans      TYPE hrobjid,
         objid      TYPE hrobjid,
         org_level  TYPE stext,
         pernr_subs TYPE pernr_d,
       END OF ty_out.

DATA gt_out TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

PARAMETERS: p_uname TYPE syuname DEFAULT sy-uname OBLIGATORY,
            p_bukrs TYPE bukrs,
            p_datum TYPE sydatum DEFAULT sy-datum,
            p_prsas TYPE zampr_prcid,
            p_prfi  TYPE zampr_prcid DEFAULT 'MIR7',
            p_steps AS CHECKBOX,
            p_cmp   AS CHECKBOX,
            p_rmir  TYPE zampr_relst DEFAULT '0010',
            p_rsat  TYPE zampr_relst DEFAULT '0401'.

START-OF-SELECTION.

* MIR7 (ZFMFFI) ile SAT (ZMM_SAT) HR onaycilari birebir
  IF p_cmp = abap_true.
    TYPES: BEGIN OF ty_cmp,
             src   TYPE char10,
             relst TYPE zampr_relst,
             stpid TYPE zampr_stpid,
             aplvl TYPE zampr_aplvl,
             uname TYPE syuname,
             plans TYPE hrobjid,
           END OF ty_cmp.
    DATA: lt_cmp  TYPE STANDARD TABLE OF ty_cmp WITH EMPTY KEY,
          lt_rm   TYPE ztffi_rel_data_alv,
          lt_rs   TYPE ztffi_rel_data_alv,
          lt_chr0 TYPE ztmpr_rel_characteristic.

    CALL FUNCTION 'ZFMFFI_GET_RELEASE_STRATEGY'
      EXPORTING
        i_docid          = 'TEST'
        i_bukrs          = p_bukrs
        i_relst          = p_rmir
        i_prcid          = 'MIR7'
        i_uname          = p_uname
        i_characteristic = lt_chr0
        i_amount         = 0
      IMPORTING
        t_rel_data       = lt_rm
      EXCEPTIONS
        OTHERS           = 1.

    CALL FUNCTION 'ZMM_SAT_GET_RELEASE_STRATEGY'
      EXPORTING
        i_docid          = 'TEST'
        i_bukrs          = p_bukrs
        i_relst          = p_rsat
        i_prcid          = 'SAT'
        i_uname          = p_uname
        i_characteristic = lt_chr0
        i_amount         = 0
      IMPORTING
        t_rel_data       = lt_rs
      EXCEPTIONS
        OTHERS           = 1.

    LOOP AT lt_rm ASSIGNING FIELD-SYMBOL(<lm>) WHERE rcode = 'HR'.
      APPEND VALUE #( src = 'MIR7' relst = p_rmir stpid = <lm>-stpid aplvl = <lm>-aplvl
                      uname = <lm>-uname plans = <lm>-plans ) TO lt_cmp.
    ENDLOOP.
    LOOP AT lt_rs ASSIGNING FIELD-SYMBOL(<ls2>) WHERE rcode = 'HR'.
      APPEND VALUE #( src = 'SAT' relst = p_rsat stpid = <ls2>-stpid aplvl = <ls2>-aplvl
                      uname = <ls2>-uname plans = <ls2>-plans ) TO lt_cmp.
    ENDLOOP.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_cmp)
                                CHANGING  t_table      = lt_cmp ).
        lo_cmp->get_functions( )->set_all( abap_true ).
        lo_cmp->get_columns( )->set_optimize( abap_true ).
        lo_cmp->display( ).
      CATCH cx_salv_msg.
    ENDTRY.
    RETURN.
  ENDIF.

* HR adimlari: surec / strateji / APLVL listesi
  IF p_steps = abap_true.
    SELECT s~prcid, s~relst, s~stpid, s~stsid, s~rcode, s~aplvl, t~ddtext
      FROM ztmpr_rel_steps AS s
      LEFT OUTER JOIN dd07t AS t ON t~domname    = 'ZAHOM_LEVEL'
                                AND t~ddlanguage = @sy-langu
                                AND t~domvalue_l = s~aplvl
      WHERE s~rcode LIKE 'HR%'
      ORDER BY s~prcid, s~relst, s~stpid, s~stsid
      INTO TABLE @DATA(lt_steps).
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_st)
                                CHANGING  t_table      = lt_steps ).
        lo_st->get_functions( )->set_all( abap_true ).
        lo_st->get_columns( )->set_optimize( abap_true ).
        lo_st->display( ).
      CATCH cx_salv_msg.
    ENDTRY.
    RETURN.
  ENDIF.

  DATA: lt_super TYPE ztthom_om_level_rel,
        lt_hom   TYPE ztthom_om_level_rel,
        lt_rel   TYPE ztthom_om_level_rel,
        lt_all   TYPE ztthom_om_level_rel,
        lt_chr   TYPE ztmpr_rel_characteristic.

* 1) SAS/SAT: ZMM_SAS_GET_RELEASE_STRATEGY 'HR' bunu cagirir
  zcl_wf_super=>agent_determination_rel(
    EXPORTING
      iv_userid     = p_uname
      iv_begda      = p_datum
      iv_endda      = p_datum
      iv_bukrs      = p_bukrs
      iv_prcid      = p_prsas
    IMPORTING
      et_org_level  = lt_super
    EXCEPTIONS
      no_data_found = 1
      OTHERS        = 2 ).
  IF sy-subrc <> 0.
    WRITE: / 'SUPER: veri yok, subrc', sy-subrc.
  ENDIF.

* 2) FFI alt katman
  CALL FUNCTION 'ZFMHOM_AGENT_DETERMINATION_REL'
    EXPORTING
      iw_userid     = p_uname
      iw_begda      = p_datum
      iw_endda      = p_datum
      iw_bukrs      = p_bukrs
      iw_prcid      = p_prfi
    IMPORTING
      ew_org_level  = lt_hom
    EXCEPTIONS
      no_data_found = 1
      OTHERS        = 2.
  IF sy-subrc <> 0.
    WRITE: / 'HOM: veri yok, subrc', sy-subrc.
  ENDIF.

* 3) FFI HRSTRUCTURE, rcode HR (sef eklemeli)
  CALL FUNCTION 'ZFMFFI_GET_RELEASE_HRSTRUCTURE'
    EXPORTING
      i_bukrs          = p_bukrs
      i_uname          = p_uname
      i_netwr          = 0
      i_prcid          = p_prfi
      i_check_limit    = space
      i_begda          = p_datum
      i_endda          = p_datum
      i_characteristic = lt_chr
      i_rcode          = 'HR'
    IMPORTING
      t_org_level_rel  = lt_rel
      t_org_level_all  = lt_all.

  PERFORM add USING 'SUPER'   lt_super.
  PERFORM add USING 'HOM'     lt_hom.
  PERFORM add USING 'HRS_REL' lt_rel.
  PERFORM add USING 'HRS_ALL' lt_all.

  IF gt_out IS INITIAL.
    WRITE: / 'Sonuc yok'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                              CHANGING  t_table      = gt_out ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->get_sorts( )->add_sort( columnname = 'LEVEL' ).
      lo_alv->get_sorts( )->add_sort( columnname = 'SRC' ).
      lo_alv->display( ).
    CATCH cx_salv_msg cx_salv_not_found cx_salv_existing cx_salv_data_error.
      WRITE: / 'ALV hatasi'.
  ENDTRY.

FORM add USING iv_src TYPE char10
               it_lvl TYPE ztthom_om_level_rel.
  LOOP AT it_lvl ASSIGNING FIELD-SYMBOL(<ls>).
    APPEND VALUE #( src        = iv_src
                    level      = <ls>-level
                    sublevel   = <ls>-sublevel
                    pernr      = <ls>-pernr
                    uname      = COND #( WHEN <ls>-pernr IS NOT INITIAL
                                         THEN zcl_wf_super=>get_uname_from_pernr( <ls>-pernr ) )
                    emp_name   = <ls>-emp_name
                    plans      = <ls>-plans
                    objid      = <ls>-objid
                    org_level  = <ls>-org_level
                    pernr_subs = <ls>-pernr_subs ) TO gt_out.
  ENDLOOP.
ENDFORM.
