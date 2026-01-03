DECLARE
    l_html CLOB := '';
BEGIN
    l_html := l_html ||
    '<style>
        /* Container for cards */
        .so-cards {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            justify-content: center;
            padding: 10px;
            background: #f4f6f5;  /* subtle page background */
        }

        /* Individual card */
        .so-card {
            box-sizing: border-box;
            width: 100%;
            max-width: 480px;
            background: #ffffff;  /* main card background */
            border: 1px solid #e2e8f0;
            border-radius: 16px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.08);  /* light shading */
            margin: 12px;
            transition: all .3s ease-in-out;
        }

        .so-card:hover {
            box-shadow: 0 8px 18px rgba(0,0,0,0.12);
            transform: translateY(-4px);
        }

        /* Header with light green background */
        .so-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: #e6f7e6;  /* lighter soft green */
            padding: 12px 16px;
            border-top-left-radius: 16px;
            border-top-right-radius: 16px;
            margin-bottom: 10px;
        }

        .so-title {
            font-size: 20px;
            font-weight: bold;
            color: #1f7a1f;
            margin: 0;
        }

        .so-soid {
            font-size: 14px;
            color: #3d6b3d;
            margin: 0;
        }

        .so-total-badge {
            background: #28a745;
            color: #fff;
            padding: 4px 12px;
            border-radius: 12px;
            font-weight: bold;
            font-size: 14px;
        }

        .so-divider {
            border: 0;
            height: 1px;
            background: #28a74533;
            margin: 10px 0;
        }

        /* Order details row */
        .so-row {
            display: flex;
            justify-content: space-between;
            font-size: 15px;
            color: #155724;
            margin-bottom: 6px;
            padding: 0 16px;
        }

        .so-label {
            font-weight: 600;
        }

        .so-value {
            font-weight: 600;
        }

        /* Image preview */
        .so-image {
            max-width: 100%;
            height: auto;
            border-radius: 12px;
            border: 1px solid #c3e6cb;
            box-shadow: 0 2px 6px rgba(40,167,69,0.1);
            margin: 10px 16px;
        }

        /* Download button */
        .so-download {
            display: inline-block;
            margin: 10px 16px 16px 16px;
            padding: 8px 12px;
            border-radius: 8px;
            background: #28a745;
            color: #fff;
            font-weight: bold;
            text-decoration: none;
        }

        .so-download:hover {
            background: #1e7a1e;
        }

        @media (max-width: 760px) {
            .so-card {
                max-width: 100%;
            }
        }
    </style>';

    l_html := l_html || '<div class="so-cards">';

    FOR r IN (
        WITH REGISTRATION AS(
            SELECT
                     SR_ID,
                     REG_NAME  
            FROM
                        AB_SETUP_REGISTRATION
            WHERE
                         REG_STATUS='Y'
                AND ORG_ID=:GV_ORG_ID
) ,
PRODUCT_NAME  AS (
           SELECT 
               ITM.ITEM_NAME || ' ' || ITM.PACKING_SIZE || '('||  ITM.UNIT ||') '|| PACKING AS ITEM_NAME,
                ITEM_ID AS ITEM_ID
        FROM   
                            AB_ITEMS_MASTER ITM
        WHERE
                      ITM.STATUS='Y'
      ORDER BY
                    ITM.ITEM_ID ASC
),
 PRODCUT_NAME_MULTIPLE AS 
 (   select  
        ASOD.SOD_ID SOD_ID,
        ASODS.SOD_IDS , 
      LISTAGG(DISTINCT ITM.ITEM_ID, ', ') WITHIN GROUP (ORDER BY ITM.ITEM_ID) AS ITEM_ID,

        LISTAGG(DISTINCT ITM.ITEM_NAME, ', ') WITHIN GROUP (ORDER BY ITM.ITEM_NAME) AS PRODUCT_NAME

FROM 
       AB_SO_ORDER_DET ASOD
       JOIN AB_SO_ORDER_DET ASODS ON ASODS.SOD_IDS = ASOD.SOD_ID
       JOIN PRODUCT_NAME ITM ON ITM.ITEM_ID = ASODS.ITEM_ID
       WHERE ASOD.ORG_ID = :GV_ORG_ID
       AND   ASOD.SOD_TYPE = '840'
GROUP BY  ASODS.SOD_IDS,  ASOD.SOD_ID
), 
CATEGORY_NAME AS (
              SELECT  
                             ALD.LOOKUP_DET_NAME AS PRODUCT_CATEGORY,
                             ALD.DET_ID AS CATEGORY_ID
                     FROM AB_LOOKUP_DETAIL ALD   
                     WHERE ALD.LOOKUP_ID  = 001    
                     AND ALD.STATUS = 'Y'    
                           
)
,LOOKUP AS(
            SELECT
                     DET_ID,
                     LOOKUP_DET_NAME
            FROM
                   AB_LOOKUP_DETAIL
            WHERE
                    STATUS='Y' 
)
,CHART_OF_ACCOUNT AS(
         SELECT
                COA_ID,
                SUB_ACCOUNT_TYPE,
                ACCOUNT_TITLE
         FROM
                AB_FIN_COA
          WHERE
                STATUS='Y'
)
,USER_APPROVAL AS (
        SELECT
            APP_IDS AS SALE_ID,
            INITCAP(CREATED_BY) ||' ('|| TO_CHAR(CREATED_ON,'DD-MON-YYYY') ||')' APPROAL_BY  ,
            CREATED_ON,
            APPROVAL_STATUS
        FROM 
              AB_USER_ACTION_APPROVAL
        WHERE 
                APP_TYPE = '718'
            AND STATUS = 'Y'
            AND APPROVAL_STATUS='APPROVED'
            AND ORG_ID=:GV_ORG_ID
) 
,NOARMAL_SALE_ORDER AS (
        SELECT          
                 
                    SO.SO_IDS,    
                    ASO.SO_ID   MM_SO_ID,    
                    ASOD.SO_ID   DD_SO_ID,    
                    ASOD.SOD_ID,     
                    SOD.ITEM_ID,  
                    ASODS.ITEM_ID MULTIPLE_ITEM_ID,
                    NVL(SUM(SOD.NO_BAGS),0) NO_BAGS       
        FROM 
                     AB_SO_ORDER_HEAD SO 
             JOIN AB_SO_ORDER_DET SOD ON SOD.SO_ID = SO.SO_ID AND SOD.STATUS = 'Y'
             JOIN AB_SO_ORDER_HEAD ASO ON ASO.SO_ID = SO.SO_IDS
             JOIN AB_SO_ORDER_DET ASOD ON ASOD.SO_ID = ASO.SO_ID
             JOIN AB_SO_ORDER_DET ASODS ON ASODS.SOD_IDS = ASOD.SOD_ID

        WHERE
                SO.ORG_ID=:GV_ORG_ID
                AND ASODS.ITEM_ID =  SOD.ITEM_ID
                AND SO.STATUS='Y'
                AND SO.SO_TYPE='SALE ORDER'
        GROUP BY
               SO.SO_IDS,
                SOD.ITEM_ID , ASO.SO_ID,ASOD.SO_ID, ASOD.SOD_ID,ASODS.ITEM_ID         

)
,ADVANCE_SALE_ORDER AS (
   
     SELECT          
                  
                    SO.SO_IDS,    
                    ASO.SO_ID   MM_SO_ID,   
                    ASOD.SO_ID   DD_SO_ID,     
                    ASOD.SOD_ID,    
                    SOD.ITEM_ID,  
                    ASODS.ITEM_ID MULTIPLE_ITEM_ID,
                    NVL(SUM(SOD.NO_BAGS),0) NO_BAGS       
        FROM 
                     AB_SO_ORDER_HEAD SO 
             JOIN AB_SO_ORDER_DET SOD ON SOD.SO_ID = SO.SO_ID AND SOD.STATUS = 'Y'
             JOIN AB_SO_ORDER_HEAD ASO ON ASO.SO_ID = SO.SO_IDS
             JOIN AB_SO_ORDER_DET ASOD ON ASOD.SO_ID = ASO.SO_ID
             JOIN AB_SO_ORDER_DET ASODS ON ASODS.SOD_IDS = ASOD.SOD_ID

        WHERE
                SO.ORG_ID=:GV_ORG_ID
                AND ASODS.ITEM_ID =  SOD.ITEM_ID
                AND SO.STATUS='Y'
                AND SO.SO_TYPE='ASO'
        GROUP BY
               SO.SO_IDS,
                SOD.ITEM_ID , ASO.SO_ID,ASOD.SO_ID, ASOD.SOD_ID,ASODS.ITEM_ID           

)
          SELECT
                            SO.SO_ID  ,
                            SOD.SOD_ID ,
                            SO.COA_ID,
                            TO_CHAR(SO.ORDER_DATE ,'DD-MON-YYYY') ORDER_DATE,
                            SO.PARTY_ORDER_NO        ,
                            SO.PAYMENT_ID,
                            SO.COMPANY_ID     ,
                            SOD.ITEM_ID       ,
                            NVL(SOD.NO_BAGS,0) CORPORATE_BAGS,
                            NVL(NSO.NO_BAGS,0) NSO_BAGS,
                            NVL(ASO.NO_BAGS,0)  ASO_NO_BAGS,
                            NVL(SOD.NO_BAGS,0) - NVL(NSO.NO_BAGS,0) - NVL(ASO.NO_BAGS,0) REMAINING_BAGS  ,
                            SOD.BAG_RATE  ,
                            SOD.NO_BAGS,         
                            SOD.TOTAL_AMOUNT       ,
                            ACCOUNT_TITLE AS PARTY_NAME,
                            ASR.REG_NAME AS COMPANY_NAME,
                            INITCAP(LOOKUP_DET_NAME) PAYMENT_TERM,
                            PNM.SOD_IDS,
                            PNM.PRODUCT_NAME ,
                            SOD.PRODUCT_CATEGORY_ID,
                            CN.CATEGORY_ID,
                           CN.PRODUCT_CATEGORY ,
                           PNM.ITEM_ID AS PNM_ITEM_ID,
                            SO.CREATED_BY||'( '|| TO_CHAR(SO.CREATED_ON,'DD-MON-YYYY HH:MI:SS AM')||')' ADD_BY
        FROM 
                          AB_SO_ORDER_HEAD SO 
                LEFT JOIN AB_SO_ORDER_DET SOD ON SOD.SO_ID = SO.SO_ID AND SOD.STATUS = 'Y'
                LEFT JOIN AB_ITEMS_MASTER ITM ON ITM.ITEM_ID = SOD.ITEM_ID AND ITM.STATUS='Y'
                LEFT JOIN CHART_OF_ACCOUNT COA ON COA.COA_ID = SO.COA_ID
                LEFT JOIN REGISTRATION  ASR ON ASR.SR_ID =  SO.COMPANY_ID 
                LEFT JOIN LOOKUP ALD ON ALD.DET_ID = SO.PAYMENT_ID 
                LEFT JOIN AB_DOCUMENT_RECORDS ADS ON ADS.DOC_TYPE_ID = SO.SO_ID
                 LEFT JOIN PRODCUT_NAME_MULTIPLE PNM ON PNM.SOD_IDS = SOD.SOD_ID
               LEFT JOIN CATEGORY_NAME CN ON CN.CATEGORY_ID = SOD.PRODUCT_CATEGORY_ID
                LEFT JOIN NOARMAL_SALE_ORDER NSO ON NSO.SO_IDS = SO.SO_ID   
                LEFT JOIN  ADVANCE_SALE_ORDER ASO ON ASO.SO_IDS= SO.SO_ID    
               
        WHERE
               SO.STATUS = 'Y'
                AND SO.SO_TYPE = '840'
                 and SO.SO_ID=:P294_COOPERATE_SALE_ID
                AND SO.ORG_ID = :GV_ORG_ID
          
        ORDER BY
                    SO.ORDER_DATE DESC

    ) LOOP

        l_html := l_html || '<div class="so-card">';

        -- Header: Product Name + Company + Total
        l_html := l_html ||
            '<div class="so-header">' ||
            '<div><p class="so-title">' || apex_escape.html(r.PRODUCT_NAME) || '</p>' ||
            '<p class="so-soid">Company: ' || apex_escape.html(r.COMPANY_NAME) || '</p></div>' ||
            '<span class="so-total-badge">Rs. ' || NVL(TO_CHAR(r.TOTAL_AMOUNT,'FM999G999G999'),'0') || '</span>' ||
            '</div>';

        l_html := l_html || '<hr class="so-divider">';

        -- Order details
        l_html := l_html || '<div class="so-row"><span class="so-label">Party:</span><span class="so-value">' || apex_escape.html(r.PARTY_NAME) || '</span></div>';
        l_html := l_html || '<div class="so-row"><span class="so-label">Order #:</span><span class="so-value">' || apex_escape.html(r.PARTY_ORDER_NO) || '</span></div>';
        l_html := l_html || '<div class="so-row"><span class="so-label">Payment Term:</span><span class="so-value">' || apex_escape.html(r.PAYMENT_TERM) || '</span></div>';
        l_html := l_html || '<div class="so-row"><span class="so-label">Bags:</span><span class="so-value">' || NVL(TO_CHAR(r.NO_BAGS),'0') || '</span></div>';
        l_html := l_html || '<div class="so-row"><span class="so-label">Rate / Bag:</span><span class="so-value">Rs. ' || NVL(TO_CHAR(r.BAG_RATE,'FM999G999G999'),'-') || '</span></div>';

 

        -- Created By at bottom
       

        l_html := l_html || '</div>'; -- close card
    END LOOP;

    l_html := l_html || '</div>'; -- close container

    -- No record message
    IF l_html IS NULL OR l_html = '<div class="so-cards"></div>' THEN
        htp.p('<div style="padding:18px;background:#e6f7e6;border:1px solid #28a745;border-radius:12px;color:#155724;">No records found.</div>');
    ELSE
        htp.p(l_html);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        htp.p('<div style="color:#b91c1c;font-weight:700;">Error: ' || apex_escape.html(SQLERRM) || '</div>');
END;
